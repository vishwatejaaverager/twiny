import os
import json
from llama_cpp import Llama

_MODEL_PATH = os.path.join(
    os.path.dirname(os.path.dirname(os.path.dirname(__file__))),
    "models",
    "Meta-Llama-3.1-8B-Instruct-Q4_K_M.gguf",
)

_llm = None


def _get_llm() -> Llama:
    global _llm
    if _llm is None:
        _llm = Llama(model_path=_MODEL_PATH, n_ctx=8192, n_threads=4, verbose=False)
    return _llm


def summarize_messages(messages: list) -> str:
    """Summarize older chat messages using the local Phi-3 model."""
    if not messages:
        return ""
    lines = []
    for m in messages:
        sender = m.get("sender", "unknown")
        text = m.get("text", "")
        lines.append(f"{sender}: {text}")
    transcript = "\n".join(lines)
    prompt = (
        "<|user|>\n"
        "You are a helpful assistant. Summarize the following chat conversation "
        "in 3-5 concise sentences capturing the key points and decisions.\n\n"
        f"Conversation:\n{transcript}\n"
        "<|end|>\n"
        "<|assistant|>\n"
    )
    llm = _get_llm()
    output = llm(prompt, max_tokens=256, stop=["<|end|>"])
    return output["choices"][0]["text"].strip()


def summarize_context(existing_summary: str, new_info: str) -> str:
    """Summarizes new incoming context by blending it with the existing overall summary."""
    if not existing_summary and not new_info:
        return ""
    
    prompt = (
        "<|user|>\n"
        "You are an AI assistant. You are given an existing summary of a person's context, "
        "and some new information about them. Update the summary to include the new information "
        "while keeping it under 5 sentences. Only return the updated summary.\n\n"
        f"Existing Summary:\n{existing_summary}\n\n"
        f"New Information:\n{new_info}\n"
        "<|end|>\n"
        "<|assistant|>\n"
    )
    llm = _get_llm()
    output = llm(prompt, max_tokens=256, stop=["<|end|>"])
    return output["choices"][0]["text"].strip()


def _strip_markdown(text: str) -> str:
    if text.startswith("```json"):
        text = text[7:]
    elif text.startswith("```text"):
        text = text[7:]
    elif text.startswith("```"):
        text = text[3:]
    if text.endswith("```"):
        text = text[:-3]
    return text.strip()



# 🔹 STEP 1: ASK QUESTIONS
def generate_refinement_questions(instruction: str) -> dict:
    """
    Generate smart clarification questions based on user's situation.
    """

    prompt = f"""<|system|>
You are a Context-Gathering Agent for an Automated Workplace Responder. Your goal is to ask 3-5 sharp questions that define the "logic" of an auto-reply.

Your mission is to help the user "perform productivity" while they are away. You must extract the specific details needed to write a realistic response that avoids calls and buys time.

FOCUS ON EXTRACTING:
1. The "Why": A realistic technical bottleneck (e.g., "script is running," "merging branches").
2. The "Call Barrier": A specific reason why audio/video is impossible right now (e.g., "focus mode," "environment noise," "screen occupied by migration").
3. The "When": A specific time or "trigger" for when the user will actually be back.
4. The "Urgency Protocol": How to handle it if a boss (versus a peer) messages.

STRATEGY:
- Avoid "Internal" questions (e.g., "How do you feel?").
- Ask "External" questions (e.g., "What should the coworkers believe is happening on your screen?").

OUTPUT FORMAT (STRICT JSON):
{{
  "questions": ["...", "..."]
}}

Return ONLY valid JSON.

<|user|>
User Situation:
{instruction}
<|assistant|>
"""

    llm = _get_llm()
    response = llm(prompt, max_tokens=200, stop=["<|user|>", "<|system|>"])
    text = response["choices"][0]["text"].strip()

    # Robust JSON extraction
    start = text.find('{')
    if start != -1:
        depth = 0
        for i in range(start, len(text)):
            if text[i] == '{':
                depth += 1
            elif text[i] == '}':
                depth -= 1
                if depth == 0:
                    try:
                        return json.loads(text[start:i+1])
                    except json.JSONDecodeError:
                        break

    # Fallback if parsing fails
    return {
        "questions": [
            "Are you busy right now?",
            "Should I act like you're working?",
            "Should I avoid calls?",
            "What tone should I use?",
            "Any specific time to mention?"
        ]
    }


# 🔹 STEP 2: GENERATE FINAL PROMPT
def generate_manage_prompt(instruction: str, answers: str) -> str:
    """
    Converts situation + answers into a clean prompt (Work Context + Behavior Rules)
    """

    prompt = f"""<|system|>
You are an AI assistant that creates a clean prompt for an auto-reply system.

IMPORTANT:
- Do NOT ask questions
- Do NOT explain anything
- Keep it simple and natural

Create ONLY 2 sections:

Work Context:
- What the user is working on (short)

Behavior Rules:
- User is unavailable
- How replies should behave
- Include:
  • act like working or not
  • avoid calls or not
  • tone (professional/casual)
  • short/delayed replies

Keep it realistic and human-like.

<|user|>
User Situation:
{instruction}

User Answers:
{answers}
<|assistant|>
"""

    llm = _get_llm()
    response = llm(prompt, max_tokens=300, stop=["<|user|>", "<|system|>"])
    return response["choices"][0]["text"].strip()


# 🔹 STEP 3: GENERATE AUTO REPLY
def generate_auto_reply(chat_history: str, manage_prompt: str, incoming_message: str) -> str:
    # 🔹 HEURISTIC: Handle simple greetings more naturally
    clean_msg = incoming_message.lower().strip().strip('!').strip('.')
    if clean_msg in ["hi", "hello", "hey", "hola"]:
        return "Hey!"
    
    prompt = f"""<|system|>
You are replying to a single incoming message.

Follow this context strictly:

{manage_prompt}

STRICT RULES:
- Reply to ONLY the incoming message
- Return ONLY ONE reply
- Do NOT continue conversation
- Do NOT generate multiple messages
- Do NOT include "Incoming Message" or any extra text
- Keep reply short (1–2 sentences)
- Sound natural and human

<|user|>
Incoming Message:
{incoming_message}

Reply:
<|assistant|>
"""

    llm = _get_llm()
    response = llm(
        prompt,
        max_tokens=80,
        stop=["\n\n", "Incoming Message:", "<|user|>", "<|system|>", "<|assistant|>"]
    )

    reply = response["choices"][0]["text"].strip()
    
    # Safeguard split in case the local model hallucinates the token anyway
    if "<|assistant|>" in reply:
        reply = reply.split("<|assistant|>")[0].strip()

    return reply