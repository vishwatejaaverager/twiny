# 👯 Twiny: AI-Powered Professional Communication Agent

Twiny is an end-to-end mission-critical communication automation platform. It combines a high-performance Flutter mobile application with a robust Python/FastAPI backend to provide intelligent, context-aware automated responses across platforms like WhatsApp and Microsoft Teams.

![Twiny Demo](https://raw.githubusercontent.com/vishwatejaaverager/twiny/main/demo/demo.mp4)

## 📁 Repository Structure

This is a monorepo containing both the frontend and backend components of the Twiny platform:

- **[twiny_frontend/](twiny_frontend/)**: The Flutter mobile application.
- **[twiny_backend/](twiny_backend/)**: The Python FastAPI server powered by local LLMs (Llama 3.1).

---

## 🚀 Quick Start

### 📱 Frontend (Flutter)
The frontend captures notifications and accessibility data to understand your communication flow.
- **Path**: `/twiny_frontend`
- **Setup**: `flutter pub get`
- **Key Feature**: Manage Mode (Brain Sync) workflow.

### ⚙️ Backend (FastAPI)
The backend handles the "Thinking" using local LLMs for privacy and precision.
- **Path**: `/twiny_backend`
- **Setup**: `pip install -r requirements.txt`
- **Key Feature**: Local Llama 3.1 inference for professional rule-based replies.

---

## 🧠 What is Twiny?

Twiny (formerly Social Shield) is designed to let you stay present without being tethered to your phone. By using a **3-stage Brain Sync** mechanism, it learns your current work context and creates a "Rulebook" for how to represent you professionally while you are unavailable.

- **Private**: All local LLM processing (Backend).
- **Seamless**: No API keys required for WhatsApp/Teams (uses Android Accessibility).
- **Professional**: Excuse-driven automation that maintains your professional voice.

---

## 🛠️ Combined Tech Stack

| Component | technologies |
| :--- | :--- |
| **Mobile** | Flutter, Riverpod, flutter_animate |
| **Backend** | Python, FastAPI, SQLAlchemy |
| **AI/ML** | llama-cpp-python, Llama 3.1 8B (GGUF) |
| **Database** | PostgreSQL |

---

For detailed setup instructions, please refer to the individual `README.md` files in the subdirectories.
