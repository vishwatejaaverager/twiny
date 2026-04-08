import json
import os
import shutil
from typing import Optional
from datetime import datetime
from fastapi import APIRouter, File, UploadFile, HTTPException, Depends, Body
from sqlalchemy.orm import Session
from app.db.postgres import get_db, engine
from app.db import models
from app.llm.model import summarize_messages

# Create tables if they don't exist
models.Base.metadata.create_all(bind=engine)

router = APIRouter()

# Local storage path (kept for backup)
DATA_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), "data")
UPLOAD_PATH = os.path.join(DATA_DIR, "uploaded_chat.json")

RAW_MESSAGES_LIMIT = 20


@router.post("/upload")
async def upload_chat(
    file: UploadFile = File(...), 
    chat_name: Optional[str] = None, 
    db: Session = Depends(get_db)
):
    """
    Accepts a multipart/form-data JSON file upload.
    - Saves the file locally (backup).
    - If chat_name is provided, attributes all messages to that person.
    - Otherwise, groups messages by chat_name (person) found in the JSON.
    - For each person/group:
        - Keeps the last 20 messages as raw text.
        - Summarizes all earlier messages into a summary.
        - Upserts the person and their chat summary in the DB.
    """
    try:
        # Ensure data directory exists
        os.makedirs(DATA_DIR, exist_ok=True)

        # Read and save file content
        content = await file.read()
        with open(UPLOAD_PATH, "wb") as buffer:
            buffer.write(content)

        # Parse JSON
        try:
            data = json.loads(content)
        except json.JSONDecodeError as e:
            raise HTTPException(status_code=422, detail=f"Invalid JSON: {e}")

        # Handle different JSON structures
        if isinstance(data, dict):
            messages_list = data.get("messages", [])
        elif isinstance(data, list):
            messages_list = data
        else:
            raise HTTPException(status_code=422, detail="Invalid JSON structure. Expected a list of messages or a dict with a 'messages' key.")

        if not messages_list:
            raise HTTPException(status_code=422, detail="No messages found in JSON.")

        # Group messages
        grouped: dict[str, list] = {}
        if chat_name:
            # If explicit chat_name provided, put all messages under it
            grouped[chat_name] = messages_list
        else:
            # Otherwise, use the chat_name from each message
            for msg in messages_list:
                name = msg.get("chat_name", "Unknown")
                grouped.setdefault(name, [])
                grouped[name].append(msg)

        results = []
        for person_name, msgs in grouped.items():
            # Split into older (to summarize) and last 20 (raw)
            older_msgs = msgs[:len(msgs)-RAW_MESSAGES_LIMIT] if len(msgs) > RAW_MESSAGES_LIMIT else []
            recent_msgs = msgs[max(0, len(msgs)-RAW_MESSAGES_LIMIT):]

            # Summarize older messages using local LLM
            summary_text = summarize_messages(older_msgs) if older_msgs else ""

            # Raw text of last 20 messages as JSON string
            raw_text = json.dumps(recent_msgs, ensure_ascii=False, indent=2)

            # Upsert person
            person = db.query(models.Person).filter_by(name=person_name).first()
            if not person:
                person = models.Person(name=person_name)
                db.add(person)
                db.flush()  # get person.id

            # Upsert chat summary
            chat_summary = db.query(models.ChatSummary).filter_by(person_id=person.id).first()
            if not chat_summary:
                chat_summary = models.ChatSummary(
                    person_id=person.id,
                    summary=summary_text,
                    raw_texts=raw_text,
                )
                db.add(chat_summary)
            else:
                # Append or replace? Original logic was replace. 
                # Given 'upload_chat' implies a fresh state or full history, we replace.
                chat_summary.summary = summary_text
                chat_summary.raw_texts = raw_text

            results.append({
                "person": person_name,
                "total_messages": len(msgs),
                "older_summarized": len(older_msgs),
                "recent_raw": len(recent_msgs),
            })

        db.commit()

        return {
            "status": "success",
            "file": file.filename,
            "chat_name_provided": chat_name,
            "people_processed": results,
        }

    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Failed to process chat: {str(e)}")


@router.post("/check")
async def check_chat(file: UploadFile = File(...), db: Session = Depends(get_db)):
    return await upload_chat(file, db)


@router.delete("/person/{chat_name}")
async def delete_person(chat_name: str, db: Session = Depends(get_db)):
    """
    Deletes all records associated with a chat_name from:
    - people
    - chat_summaries
    - brain_sync
    """
    try:
        person = db.query(models.Person).filter_by(name=chat_name).first()
        if not person:
            raise HTTPException(status_code=404, detail=f"Person '{chat_name}' not found")

        # 1. Delete BrainSync
        db.query(models.BrainSync).filter_by(person_id=person.id).delete()
        
        # 2. Delete ChatSummary
        db.query(models.ChatSummary).filter_by(person_id=person.id).delete()
        
        # 3. Delete Person
        db.delete(person)
        
        db.commit()
        return {"status": "success", "message": f"All data for '{chat_name}' has been deleted."}
        
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Failed to delete person: {str(e)}")


@router.post("/update_message")
async def update_message(payload: dict = Body(...), db: Session = Depends(get_db)):
    """
    Manually appends a single message to a person's chat history.
    """
    chat_name = payload.get("chat_name")
    sender = payload.get("sender")
    text = payload.get("text")
    
    if not chat_name or not sender or not text:
        raise HTTPException(status_code=400, detail="chat_name, sender, and text are required")
        
    person = db.query(models.Person).filter_by(name=chat_name).first()
    if not person:
        person = models.Person(name=chat_name)
        db.add(person)
        db.flush()
        
    chat_summary = db.query(models.ChatSummary).filter_by(person_id=person.id).first()
    
    current_messages = []
    if chat_summary and chat_summary.raw_texts:
        try:
            current_messages = json.loads(chat_summary.raw_texts)
        except:
            pass
            
    current_messages.append({
        "sender": sender,
        "text": text,
        "timestamp": datetime.utcnow().isoformat()
    })
    
    # Maintain RAW_MESSAGES_LIMIT
    if len(current_messages) > RAW_MESSAGES_LIMIT:
        current_messages = current_messages[len(current_messages)-RAW_MESSAGES_LIMIT:]
        
    raw_text_json = json.dumps(current_messages, ensure_ascii=False, indent=2)
    
    if not chat_summary:
        chat_summary = models.ChatSummary(
            person_id=person.id,
            raw_texts=raw_text_json
        )
        db.add(chat_summary)
    else:
        chat_summary.raw_texts = raw_text_json
        
    db.commit()
    return {"status": "success", "message": "Chat history updated."}
