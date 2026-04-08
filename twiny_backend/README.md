# 🤖 Automated Workplace Responder (AWR)

An AI-powered auto-reply system designed to manage workplace availability through a three-stage "Manage Mode" workflow. AWR uses local LLMs (Llama 3.1) to generate context-aware, professional responses that help you "perform productivity" while away from your desk.

---

## 🚀 Features
- **Brain Sync (Manage Mode)**: A multi-stage interactive setup to define your active mindset and rules.
- **Local LLM**: Powered by `llama-cpp-python` and Llama 3.1 8B Instruct for private, offline processing.
- **Smart History**: Summarizes older chats to maintain relevant context without exceeding LLM context limits.
- **RESTful API**: Fast and clean endpoints built with FastAPI.

---

## 🛠️ Tech Stack
- **Backend**: Python 3.10+, FastAPI, Uvicorn
- **Database**: PostgreSQL with SQLAlchemy ORM
- **Inference**: llama-cpp-python
- **Model**: Meta-Llama-3.1-8B-Instruct (GGUF)

---

## 📋 Prerequisites
- **PostgreSQL**: Ensure you have a running instance.
- **Python 3.10+**
- **LLM Model File**: Download the [Llama-3.1-8B-Instruct-GGUF](https://huggingface.co/lmstudio-community/Meta-Llama-3.1-8B-Instruct-GGUF) and place it in the `models/` directory.

---

## ⚙️ Installation & Setup

### 1. Environment Setup
```bash
# Create and activate virtual environment
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt
```

### 2. Database Configuration
Create a PostgreSQL database named `llm_chat`. You can configure connection details via environment variables:
- `DB_USER` (default: `postgres`)
- `DB_PASSWORD` (default: `0000`)
- `DB_HOST` (default: `localhost`)
- `DB_NAME` (default: `llm_chat`)

### 3. Model Setup
Ensure the model file exists at the following path:
`models/Meta-Llama-3.1-8B-Instruct-Q4_K_M.gguf`

---

## 🏃 Running the Application

Start the FastAPI server:
```bash
python3 main.py
```
The API will be available at `http://localhost:8000`.
Access the interactive documentation at `http://localhost:8000/docs`.

---

## 🧠 Brain Sync Workflow (End-to-End)

Follow these steps to configure the AI responder for a specific contact.

### Stage 1: The Architect (Discovery)
Send a vague intent to get clarifying questions.
```bash
curl -X POST http://localhost:8000/api/notification/brain_sync/questions \
     -H "Content-Type: application/json" \
     -d '{
       "context_data": "I want to sound busy dealing with a critical server migration."
     }'
```

### Stage 2: The Legislator (Rule Generation)
Send your answers to synthesized context and behavior rules.
```bash
curl -X POST http://localhost:8000/api/notification/brain_sync/finalize \
     -H "Content-Type: application/json" \
     -d '{
       "original_intent": "Busy with server migration",
       "user_answers": "1. Script is running. 2. No calls. 3. Be professional but brief."
     }'
```

### Stage 3: Activation (Save Context)
Persist the resulting "Rulebook" for a specific contact.
```bash
curl -X POST "http://localhost:8000/api/notification/brain_sync" \
     -H "Content-Type: application/json" \
     -d '{
       "chat_name": "Prashant Pathak",
       "context_data": "### Work Context\n- Migration Script Active...\n### Behavior Rules\n- Brief replies only...\n- Professional tone..."
     }'
```

---

## 💬 Execution: Generating Replies
Once Brain Sync is activated, you can generate auto-replies for incoming messages.

```bash
curl -X POST http://localhost:8000/api/notification/reply \
     -H "Content-Type: application/json" \
     -d '{
       "chat_name": "Prashant Pathak",
       "message": "Hey, is the migration done yet?"
     }'
```

---

## 🧪 Testing
Run the provided test scripts to verify the system:
```bash
python3 test_manage_mode.py
python3 test_brain_sync.py
```

---

## 📁 Project Structure
- `app/api/`: API route definitions.
- `app/llm/`: Model loading and prompt engineering.
- `app/db/`: Postgres schema and session management.
- `models/`: Destination for GGUF model files.
- `main.py`: Entry point for the FastAPI application.
