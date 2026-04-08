import asyncio
from app.db.postgres import SessionLocal
from app.api.chat import upload_chat
from fastapi import UploadFile
from io import BytesIO

async def main():
    with open("data/uploaded_chat.json", "rb") as f:
        content = f.read()

    file_obj = BytesIO(content)
    upload_file = UploadFile(filename="test_chat.json", file=file_obj)

    db = SessionLocal()
    try:
        res = await upload_chat(upload_file, db)
        print("API Response:")
        print(res)
    finally:
        db.close()

if __name__ == "__main__":
    asyncio.run(main())
