import sys
import json
from app.llm.model import (
    generate_refinement_questions,
    generate_manage_prompt,
    generate_auto_reply
)

def main():
    print("=== Testing Updated Manage Mode Pipeline (Interactive) ===\n")

    # STAGE 1: ASK QUESTIONS
    print("Step 1: Ask Questions (generate_refinement_questions)")
    print("Please describe your current situation.")
    instruction = input("> Situation / Instructions: ")
    if not instruction.strip():
        print("Empty string provided, exiting.")
        return

    print("\n[Thinking...] Running Step 1...\n")
    questions_json = generate_refinement_questions(instruction)
    
    questions = questions_json.get('questions', [])

    # Interactive Q&A
    print("The AI has some questions to clarify:")
    answers = []
    for q in questions:
        # In the new logic, q is just a string (not a dict)
        print(f"\nQ: {q}")
        ans = input("> A: ")
        answers.append({"question": q, "answer": ans})

    # STAGE 2: GENERATE FINAL PROMPT
    print("-" * 50)
    print("\nStep 2: Generate Final Prompt (generate_manage_prompt)")
    
    # Format the answers into a string
    user_answers_str = ""
    for ans in answers:
        user_answers_str += f"Q: {ans['question']}\nA: {ans['answer']}\n"

    print("\n[Thinking...] Creating Manage Prompt...\n")
    manage_prompt = generate_manage_prompt(instruction, user_answers_str)
    
    print("--- Output (Manage Prompt) ---")
    print(manage_prompt)
    print("-------------------------------------------------------")

    # STAGE 3: GENERATE AUTO REPLY
    print("\nStep 3: Auto Reply (generate_auto_reply)")
    print("Now, let's test how this agent responds based on the Management Prompt above.")
    
    current_chat_history = ""
    while True:
        incoming = input("\n> Incoming Message from Lead/Colleague (or type 'exit' to quit): ")
        if incoming.lower().strip() == 'exit' or not incoming.strip():
            print("Exiting test.")
            break
        
        print("\n[Thinking...] Running Auto Reply...\n")
        reply = generate_auto_reply(current_chat_history, manage_prompt, incoming)
        
        print(f"--- Operator Auto-Reply ---")
        print(f"{reply}")
        
        # Append the exchange to the active chat history to maintain context
        current_chat_history += f"\nThem: {incoming}\nMe: {reply}"

    print("\n=== End of Test ===")

if __name__ == "__main__":
    main()
