import asyncio
import json
from io import BytesIO
from fastapi import UploadFile
from app.db.postgres import SessionLocal
from app.api.chat import upload_chat
from app.db import models

async def test_individual_upload():
    print("Testing individual upload with chat_name parameter...")
    db = SessionLocal()
    try:
        # Sample data: just a list of messages
        messages = [
            {"sender": "User1", "text": "Hello, how are you?", "timestamp": "2023-10-01T10:00:00Z"},
            {"sender": "AI", "text": "I am fine, thank you!", "timestamp": "2023-10-01T10:00:10Z"}
        ]
        content = json.dumps(messages).encode("utf-8")
        file_obj = BytesIO(content)
        upload_file = UploadFile(filename="individual_chat.json", file=file_obj)

        res = await upload_chat(upload_file, chat_name="TestPerson", db=db)
        print("Response:", res)

        # Verify in DB
        person = db.query(models.Person).filter_by(name="TestPerson").first()
        assert person is not None, "Person 'TestPerson' should be created"
        
        summary = db.query(models.ChatSummary).filter_by(person_id=person.id).first()
        assert summary is not None, "ChatSummary should be created"
        
        raw_msgs = json.loads(summary.raw_texts)
        assert len(raw_msgs) == 2, f"Should have 2 messages, got {len(raw_msgs)}"
        print("Individual upload test passed!")

    finally:
        db.close()

async def test_batch_upload():
    print("\nTesting batch upload (standard format)...")
    db = SessionLocal()
    try:
        # Sample data: dict with 'messages' key
        data = {
            "messages": [
                {"chat_name": "BatchPerson1", "sender": "User", "text": "Msg 1"},
                {"chat_name": "BatchPerson2", "sender": "User", "text": "Msg 2"}
            ]
        }
        content = json.dumps(data).encode("utf-8")
        file_obj = BytesIO(content)
        upload_file = UploadFile(filename="batch_chat.json", file=file_obj)

        res = await upload_chat(upload_file, db=db)
        print("Response:", res)

        # Verify in DB
        p1 = db.query(models.Person).filter_by(name="BatchPerson1").first()
        p2 = db.query(models.Person).filter_by(name="BatchPerson2").first()
        assert p1 is not None and p2 is not None, "Both persons should be created"
        print("Batch upload test passed!")

    finally:
        db.close()

if __name__ == "__main__":
    asyncio.run(test_individual_upload())
    asyncio.run(test_batch_upload())
