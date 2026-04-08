from sqlalchemy import Column, Integer, String, Text, ForeignKey, DateTime
from sqlalchemy.orm import relationship
from datetime import datetime
from app.db.postgres import Base


class Person(Base):
    """Represents a chat participant (identified by chat_name)."""
    __tablename__ = "people"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, unique=True, index=True, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)

    chats = relationship("ChatSummary", back_populates="person")
    brain_syncs = relationship("BrainSync", back_populates="person", uselist=False)



class ChatSummary(Base):
    """
    Stores chat history per person.
    - summary: summarized text of all messages BEFORE the last 20
    - raw_texts: the last 20 messages stored as raw JSON text
    """
    __tablename__ = "chat_summaries"

    id = Column(Integer, primary_key=True, index=True)
    person_id = Column(Integer, ForeignKey("people.id"), nullable=False)
    summary = Column(Text, nullable=True)   # summarized older messages
    raw_texts = Column(Text, nullable=True)  # last 20 messages (JSON string)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    person = relationship("Person", back_populates="chats")

class BrainSync(Base):
    """
    Stores context/heads-up info given to the AI for a person.
    """
    __tablename__ = "brain_sync"

    id = Column(Integer, primary_key=True, index=True)
    person_id = Column(Integer, ForeignKey("people.id"), nullable=False, unique=True)
    raw_context_data = Column(Text, nullable=True)     # Raw unsummarized context 
    summary_context_data = Column(Text, nullable=True) # AI summarized context
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    person = relationship("Person", back_populates="brain_syncs")
