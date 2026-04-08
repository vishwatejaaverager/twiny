import json
import os
import re
from datetime import datetime
from fastapi import APIRouter, HTTPException, Body, Depends
from sqlalchemy.orm import Session

from app.db.postgres import get_db
from app.db import models
from app.llm.model import summarize_context, generate_auto_reply, generate_refinement_questions, generate_manage_prompt

router = APIRouter()

@router.post("/brain_sync/questions")
async def get_brain_questions(payload: dict = Body(...)):
    """
    STAGE 1: Returns 3 tactical questions based on a vague situation.
    """
    instruction = payload.get("context_data")
    chat_history = payload.get("chat_history", "No prior chat history provided for context.")
    if not instruction:
        print(f"[Brain Sync Error] Missing 'context_data' in /brain_sync/questions payload")
        raise HTTPException(status_code=400, detail="context_data is required")

    print(f"\n{'='*50}\n[Brain Sync] The Architect is generating questions (Stage 1)...")
    print(f"[Brain Sync] Input Instruction: '{str(instruction)[:100]}...'")
    questions_json = generate_refinement_questions(instruction)
    print(f"[Brain Sync] Architect successfully generated {len(questions_json.get('questions', []))} questions.\n{'='*50}")
    return {
        "stage": "needs_clarification",
        "questions": questions_json.get("questions", [])
    }

@router.post("/brain_sync/finalize")
async def finalize_brain(payload: dict = Body(...)):
    """
    STAGE 2: Synthesizes intent + answers into an 'Active Mindset'.
    """
    original_intent = payload.get("original_intent")
    user_answers = payload.get("user_answers")
    
    if not original_intent or not user_answers:
        print(f"[Brain Sync Error] Missing 'original_intent' or 'user_answers' in /brain_sync/finalize payload")
        raise HTTPException(status_code=400, detail="original_intent and user_answers are required")

    print(f"\n{'='*50}\n[Brain Sync] The Legislator is converting context into a Rulebook (Stage 2)...")
    print(f"[Brain Sync] Original Intent: '{str(original_intent)[:50]}...'")
    print(f"[Brain Sync] User Answers: '{str(user_answers)[:50]}...'")
    
    final_state = generate_manage_prompt(str(original_intent), str(user_answers))
    print(f"[Brain Sync] Legislator successfully forged Rulebook (Length: {len(final_state)})\n{'='*50}")
    return {"stage": "complete", "brain_state": final_state}

@router.post("/brain_sync")
async def update_brain_sync(payload: dict = Body(...), db: Session = Depends(get_db)):
    """
    Updates the brain sync context data for a person with the ALREADY FINALIZED prompt.
    """
    chat_name = payload.get("chat_name")
    final_context = payload.get("context_data")

    if not chat_name or not final_context:
        print(f"[Brain Sync Error] Missing 'chat_name' or 'context_data' in /brain_sync payload")
        raise HTTPException(status_code=400, detail="chat_name and context_data are required")

    print(f"\n{'='*50}\n[Brain Sync] Saving finalized context for chat_name: '{chat_name}'")
    print(f"[Brain Sync] Incoming Rulebook Length: {len(final_context)} characters")
    
    # 1. Ensure Person exists
    person = db.query(models.Person).filter_by(name=chat_name).first()
    if not person:
        print(f"[Brain Sync] Person '{chat_name}' not found, creating new person.")
        person = models.Person(name=chat_name)
        db.add(person)
        db.flush()

    # 2. Get or create BrainSync record
    brain_sync = db.query(models.BrainSync).filter_by(person_id=person.id).first()
    
    if not brain_sync:
        print(f"[Brain Sync] Creating new BrainSync record for {chat_name}")
        brain_sync = models.BrainSync(
            person_id=person.id,
            raw_context_data=final_context,
            summary_context_data=final_context,
        )
        db.add(brain_sync)
    else:
        # REPLACE: always overwrite with the latest context
        brain_sync.raw_context_data = final_context
        brain_sync.summary_context_data = final_context
        print(f"[Brain Sync] Replaced context for '{chat_name}' (new length: {len(final_context)})")


    db.commit()
    print(f"[Brain Sync] Successfully committed to DB for '{chat_name}'")

    return {
        "status": "success",
        "chat_name": chat_name,
        "brain_sync_raw": brain_sync.raw_context_data
    }


@router.post("/reply")
async def get_notification_reply(payload: dict = Body(...), db: Session = Depends(get_db)):
    chat_name = payload.get("chat_name")
    message = payload.get("message")
    
    if not chat_name or not message:
        raise HTTPException(status_code=400, detail="chat_name and message are required")

    print(f"\n[Reply API] Processing request for chat_name: '{chat_name}'")
    print(f"[Reply API] Incoming message: '{message}'")
    
    person = db.query(models.Person).filter_by(name=chat_name).first()
    
    chat_history_text = ""
    brain_sync_text = "No additional context."

    if not person:
        print(f"[Reply API Error] Person '{chat_name}' not found in DB. Skipping auto-reply.")
        raise HTTPException(
            status_code=404, 
            detail=f"Person '{chat_name}' not found. No Brain Sync rules available."
        )

    print(f"[Reply API] Found person in DB (ID: {person.id})")
    # 1. Load Brain Sync if available
    brain_sync = db.query(models.BrainSync).filter_by(person_id=person.id).first()
    if brain_sync and brain_sync.raw_context_data:
        brain_sync_text = brain_sync.raw_context_data
        print(f"[Reply API] Loaded RAW Brain Sync context ({len(brain_sync_text)} chars)")

    # 2. Load Chat History
    chat_summary = db.query(models.ChatSummary).filter_by(person_id=person.id).first()
    if chat_summary:
        chat_history_text = chat_summary.summary or ""
        # Append a bit of raw text if we want richer context, but summary is usually enough
        if chat_summary.raw_texts:
            try:
                # quick parse to grab the last few messages
                raw_messages = json.loads(chat_summary.raw_texts)
                last_few = [f"{m.get('sender', 'unknown')}: {m.get('text', '')}" for m in raw_messages[-5:]]
                chat_history_text += "\nRecent exact messages:\n" + "\n".join(last_few)
                print(f"[Reply API] Loaded chat history summary + {len(last_few)} recent messages")
            except:
                print("[Reply API] Failed to parse raw_texts for chat history")
                pass
    
    # 3. Generate reply using the LLM setup
    print(f"[Reply API] Triggering Operator LLM to generate auto-reply...")
    reply = generate_auto_reply(
        chat_history=chat_history_text,
        manage_prompt=brain_sync_text,
        incoming_message=message
    )
    print(f"[Reply API] Operator successfully generated reply: '{reply}'")
    
    # 4. Persistence: Save message and reply to the database
    try:
        if not person:
            # Should have already been checked but let's be safe
            person = db.query(models.Person).filter_by(name=chat_name).first()
            if not person:
                person = models.Person(name=chat_name)
                db.add(person)
                db.flush()

        chat_summary = db.query(models.ChatSummary).filter_by(person_id=person.id).first()
        
        # Current messages list
        current_messages = []
        if chat_summary and chat_summary.raw_texts:
            try:
                current_messages = json.loads(chat_summary.raw_texts)
            except:
                pass
        
        # Append incoming message
        current_messages.append({
            "sender": "other",
            "text": message,
            "timestamp": datetime.utcnow().isoformat()
        })
        
        # Append AI reply
        current_messages.append({
            "sender": "me",
            "text": reply,
            "timestamp": datetime.utcnow().isoformat()
        })
        
        # Keep only the last 20 (sliding window)
        LIMIT = 20
        if len(current_messages) > LIMIT:
            current_messages = current_messages[len(current_messages)-LIMIT:]
            
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
        print(f"[Reply API] Persisted message + reply to DB for '{chat_name}'")
    except Exception as e:
        db.rollback()
        print(f"[Reply API] Persistence failed: {e}")

    return {"reply": reply}
