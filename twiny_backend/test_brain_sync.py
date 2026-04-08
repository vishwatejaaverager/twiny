import asyncio
from app.api.notification import get_brain_questions, finalize_brain, update_brain_sync, get_notification_reply
from app.db.postgres import SessionLocal

async def main():
    db = SessionLocal()
    try:
        print("========== BRAIN SYNC SETUP (STAGE 1) ==========")
        original_intent = input("\nEnter your initial vague Brain Sync situation:\n> ")
        
        print("\n[AI] Generating tactical questions...")
        # Simulating hitting POST /brain_sync/questions
        res_questions = await get_brain_questions({"context_data": original_intent, "chat_history": ""})
        
        if res_questions.get("stage") == "needs_clarification":
            print("\n------------- CLARIFICATION NEEDED -------------")
            questions = res_questions.get("questions", [])
            answers_text = ""
            for i, q in enumerate(questions, 1):
                ans = input(f"Q{i}: {q}\n> ")
                answers_text += f"Q: {q}\nA: {ans}\n"
        
        print("\n========== FINALIZING LOGIC (STAGE 2) ==========")
        print("[AI] Synthesizing 'Active Mindset'...")
        # Simulating hitting POST /brain_sync/finalize
        res_final = await finalize_brain({
            "original_intent": original_intent,
            "user_answers": answers_text
        })
        
        if res_final.get("stage") == "complete":
            final_state_text = res_final.get("brain_state", "")
            print("\n------------- MASTER MINDSET -------------")
            print(final_state_text)
            print("------------------------------------------")
            
            confirm = input("\nDo you accept this Mindset to be saved? (y/n):\n> ").strip()
            if confirm.lower() not in ['y', 'yes', '']:
                print("Aborting. Please restart the sync.")
                return

            print("\nSaving your Active Mindset to the database...")
            payload_save = {
                "chat_name": "LevelUpGenie - Team",
                "context_data": final_state_text
            }
            await update_brain_sync(payload_save, db)
            print("Success! Brain Sync is now active.")
        else:
            print("Failed to finalize brain state.")
            return

        print("\n\n========== NOTIFICATION SIMULATOR (STAGE 3) ==========")
        print("You can now simulate receiving messages from 'LevelUpGenie - Team'.")
        while True:
            msg = input("\nIncoming message (type 'exit' to quit):\n> ")
            if msg.lower() == 'exit':
                break
                
            payload_reply = {
                "chat_name": "LevelUpGenie - Team",
                "message": msg
            }
            res_reply = await get_notification_reply(payload_reply, db)
            print(f"\n[Auto-Reply from AI]\n{res_reply.get('reply')}")

    except Exception as e:
        print("Error:", e)
    finally:
        db.close()

if __name__ == "__main__":
    asyncio.run(main())
