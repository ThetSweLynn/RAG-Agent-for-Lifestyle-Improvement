# llm_setup.py
from langchain_google_genai import ChatGoogleGenerativeAI

# Initialize LLMs
llm = ChatGoogleGenerativeAI(model='gemini-2.0-flash', temperature=0.3)