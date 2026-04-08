from fastapi import FastAPI
from app.api.chat import router as chat_router
from app.api.notification import router as notification_router
import uvicorn

app = FastAPI(title="Chat Upload API")

# Include the routers
app.include_router(chat_router, prefix="/api/chat", tags=["chat"])
app.include_router(notification_router, prefix="/api/notification", tags=["notification"])

@app.get("/")
async def root():
    return {"message": "Chat Upload API is running"}

if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
