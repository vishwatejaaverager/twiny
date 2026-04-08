from app.llm.model import refine_user_prompt

# Initial user request
instruction = "I am going out so my lead said to coplete s3 bucket video tasks so manage them by giving excuses ill be back by 5 o clock"

# Will likely return clarifying questions
response = refine_user_prompt(instruction)
print("Assistant:", response)

# User answers the questions, we pass the history back to the function
chat_history = [
    {"role": "user", "content": instruction},
    {"role": "assistant", "content": response},
    {"role": "user", "content": "The tone should be comedic, aimed at young adults, and focus on a pirate who is actually afraid of the dark."}
]

# Provide instruction again (or you can just pass the final answer as instruction)
final_quality_prompt = refine_user_prompt(
    "Help me refine my prompt based on the answers I just provided.", 
    chat_history=chat_history
)
print("Assistant:", final_quality_prompt)
