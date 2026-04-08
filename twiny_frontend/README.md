# <p align="center"><img src="assets/twiny.png" width="48" height="48" /><br/>Twiny: Your AI-Powered Communication Agent</p>

![Twiny App Mockup](assets/readme_header.png)

## 🚀 Overview

**Twiny** (formerly Social Shield) is a state-of-the-art Flutter application designed to bridge the gap between human communication and AI-driven automation. It acts as a professional communication agent that intelligently captures, analyzes, and responds to messages across major platforms like **WhatsApp** and **Microsoft Teams**.

Built with a focus on professional presence and excuse-driven automation, Twiny allows users to stay connected and responsive even when they are unavailable, using a sophisticated "Brain Sync" mechanism to mirror their professional style and current context.

---

## ✨ Key Features

### 🧠 Manage Mode (Brain Sync)
The core of Twiny is its interactive **Brain Sync** workflow, which transforms a simple AI into a context-aware professional agent through a 3-stage architectural pipeline:

1.  **The Architect (Discovery):** Define your current context (e.g., "In a marathon meeting," "Traveling with limited connectivity"). The AI probes with deep discovery questions to understand your intent.
2.  **The Legislator (Rulebook Generation):** Based on your answers, Twiny generates a Markdown-based **Brain State**—a set of rules and protocols that define how the agent should represent you.
3.  **The Operator (Activation):** Activate the agent for specific contacts. The AI will now handle incoming messages using the rules you've defined and verified.

### 📱 Multi-Platform Capture
Twiny uses advanced Android services to monitor and capture communication without requiring direct API integrations from third-party apps:
- **Notification Listener:** Captures incoming message previews.
- **Accessibility Service:** Enables deep screen-reading capabilities to capture full chat histories and context in real-time.

### 🧪 Simulation Environment
Before going live, test your "Brain State" in a safe simulation. Input trial messages and see how your AI Twin would respond, allowing for fine-tuning of your professional rules.

### 🎨 Modern, Premium UI
- **Glassmorphism Design:** A sleek, modern interface with neon purple and emerald green accents.
- **Fluid Animations:** Powered by `flutter_animate` for a "living" UI experience.
- **Dark Mode Native:** Designed from the ground up for professional, low-strain usage.

---

## 🛠 Technology Stack

- **Framework:** [Flutter](https://flutter.dev/) (SDK ^3.10.4)
- **State Management:** [Riverpod](https://riverpod.dev/) for robust, testable logic.
- **Animations:** `flutter_animate` for high-performance micro-interactions.
- **Navigation:** Custom Route-based navigation with `page_transition`.
- **Styling:** Custom Design System with primary colors `#7C3AED` (Purple) and `#06D6A0` (Green).
- **Communication:** [HTTP](https://pub.dev/packages/http) for backend sync and [Flutter Markdown](https://pub.dev/packages/flutter_markdown) for rulebook rendering.

---

## 🏗 Project Structure

```text
lib/
├── core/             # Design system, constants, and utilities
├── features/         # Feature-based architecture
│   ├── auth/         # Authentication flow
│   ├── dashboard/    # Main capture & Brain Sync UI
│   └── onboarding/   # Initial setup & permissions
├── models/           # Data structures
├── routes/           # Navigation logic
└── services/         # Notification & API services
```

---

## 📥 Getting Started

### Prerequisites

- Flutter SDK ^3.10.4
- Android Studio / VS Code
- An Android Physical Device (Required for Accessibility/Notification services)

### Setup Instructions

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/your-repo/twiny.git
    cd twiny
    ```

2.  **Install dependencies:**
    ```bash
    flutter pub get
    ```

3.  **Run the application:**
    ```bash
    flutter run
    ```

4.  **Enable Permissions:**
    - Upon launching, Twiny will request **Contact Access**.
    - You must manually enable **Accessibility Service** and **Notification Access** in Android Settings (the app provides direct links).

---

## 🛡 Privacy & Security

Twiny is built with a **PrivateAI** first philosophy. While messages are processed via our secure backend to leverage advanced LLM capabilities, we prioritize data isolation and provide tools for users to clear local and server-side data at any time.

---

<p align="center">Made with ❤️ for the future of communication.</p>
