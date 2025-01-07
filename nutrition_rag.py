import os
import google.generativeai as genai
import speech_recognition as sr
from gtts import gTTS
from io import BytesIO
from pygame import mixer
from dotenv import load_dotenv
from datetime import date
import json
import textwrap
from langchain_google_genai import ChatGoogleGenerativeAI, GoogleGenerativeAIEmbeddings
from langchain_chroma import Chroma
from langchain_community.document_loaders import PyPDFLoader, DirectoryLoader
from langchain.text_splitter import RecursiveCharacterTextSplitter
from langchain.chains import RetrievalQA

# Initialize mixer for text-to-speech
mixer.init()
today = str(date.today())

# Load environment variables
dotenv_path = os.path.join(os.path.dirname(__file__), '.env')
load_dotenv(dotenv_path)
api_key = os.environ.get("GOOGLE_API_KEY")
genai.configure(api_key=api_key)

# Vector Store Configuration
persist_directory = 'db'
vector_store_exists = os.path.exists(persist_directory)
embeddings = GoogleGenerativeAIEmbeddings(model="models/embedding-001")

# Load or Create Vector Store
if vector_store_exists:
    vectordb = Chroma(persist_directory=persist_directory, embedding_function=embeddings)
else:
    loader = DirectoryLoader('Nutrition Data', glob='./*.pdf', loader_cls=PyPDFLoader)
    raw_data = loader.load()
    
    text_splitter = RecursiveCharacterTextSplitter(chunk_size=1000, chunk_overlap=0)
    nutrition_data = text_splitter.split_documents(raw_data)
    
    vectordb = Chroma.from_documents(documents=nutrition_data, 
                                     embedding_function=embeddings,
                                     persist_directory=persist_directory)

retriever = vectordb.as_retriever(search_kwargs={"k":5})

# Initialize the LLM
llm = ChatGoogleGenerativeAI(model='gemini-1.5-pro', temperature=0.7)

# Custom Memory Handler
# Custom Memory Handler
class FileBasedMemory:
    def __init__(self, memory_file='chat_history.json'):
        self.memory_file = memory_file
        self.history = self.load_memory()

    def load_memory(self):
        if os.path.exists(self.memory_file):
            with open(self.memory_file, 'r') as file:
                return json.load(file)
        return []

    def save_memory(self):
        # Save the history with indentation for better readability
        with open(self.memory_file, 'w') as file:
            json.dump(self.history, file, indent=4)

    def append_to_history(self, user_input, bot_response):
        self.history.append({'user': user_input, 'bot': bot_response})
        self.save_memory()

    def get_history(self):
        return '\n'.join([f"User: {entry['user']}\nBot: {entry['bot']}" for entry in self.history])

# Initialize Memory
memory = FileBasedMemory(memory_file='chat_history.json')

# RetrievalQA Setup
qa_chain = RetrievalQA.from_chain_type(
    llm=llm,
    chain_type="stuff",
    retriever=retriever,
    return_source_documents=True  # Enable source document return
)

# Helper Functions
def wrap_text_preserve_newlines(text, width=110):
    lines = text.split('\n')
    wrapped_lines = [textwrap.fill(line, width=width) for line in lines]
    return '\n'.join(wrapped_lines)

def process_llm_response(llm_response):
    # Extract and wrap the main response text
    final_response = wrap_text_preserve_newlines(llm_response['result'])
    
    # Add source document information
    source_info = "\n\nSources:\n"
    if 'source_documents' in llm_response and llm_response["source_documents"]:
        for i, source in enumerate(llm_response["source_documents"]):
            source_name = source.metadata.get('source', 'Unknown Source')
            source_info += f"{i + 1}. {source_name}\n"
    else:
        source_info += "No sources found.\n"

    # Combine the main response with the source information
    final_response_with_sources = final_response + source_info

    return final_response_with_sources

# RAG Agent Function
def call_rag_agent(query):
    # Step 1: Retrieve relevant chunks from vector store (Nutrition Data PDFs)
    try:
        retrieved_docs = retriever.invoke(query)
    except Exception as e:
        print(f"Error during retrieval: {e}")
        retrieved_docs = []

    # Extract text from the retrieved documents, or notify if no relevant text is found
    if retrieved_docs:
        retrieved_text = "\n".join([doc.page_content for doc in retrieved_docs[:3]])
        context_info = f"Here is some information from your Nutrition Data PDFs that might help:\n{retrieved_text}\n"
    else:
        context_info = "No relevant information found in Nutrition Data PDFs.\n"

    # Step 2: Get conversation history
    conversation_history = memory.get_history()

    # Step 3: Construct the prompt using the retrieved context and conversation history
    custom_prompt = (
        "You are an AI expert specializing in nutrition and fitness, providing personalized dietary and fitness recommendations. "
        "Answer user queries concisely and accurately, relying strictly on the provided knowledge base to ensure faithfulness. "
        "Cite sources from the knowledge base where relevant, and avoid speculative or unsupported statements."
    )

    
    prompt = (
        f"{custom_prompt}\n"
        f"{context_info}\n"
        f"Previous Conversation:\n{conversation_history}\n"
        f"User Query: {query}\nAI:"
    )

    # Step 4: Get the LLM response
    response = qa_chain.invoke(prompt)
    
    # Step 5: Process response to include source information
    final_response = process_llm_response(response)

    # Step 6: Save conversation to memory
    memory.append_to_history(query, final_response)

    return final_response

# Text-to-Speech Function
def speak_text(text):
    try:
        cleaned_text = text.split("\n\nSources:")[0].replace('\n', ' ').strip()

        if len(cleaned_text) > 200:
            chunks = [cleaned_text[i:i+200] for i in range(0, len(cleaned_text), 200)]
            for chunk in chunks:
                tts = gTTS(text=chunk, lang='en')
                with BytesIO() as mp3_file:
                    tts.write_to_fp(mp3_file)
                    mp3_file.seek(0)
                    mixer.music.load(mp3_file)
                    mixer.music.play()
                    while mixer.music.get_busy():
                        pass
        else:
            tts = gTTS(text=cleaned_text, lang='en')
            with BytesIO() as mp3_file:
                tts.write_to_fp(mp3_file)
                mp3_file.seek(0)
                mixer.music.load(mp3_file)
                mixer.music.play()
                while mixer.music.get_busy():
                    pass
    except Exception as e:
        print(f"Error speaking text: {e}")

# Logging Function
def append2log(text):
    global today
    fname = f'chatlog-{today}.txt'
    with open(fname, "a", encoding='utf-8') as f:
        f.write(text + "\n")

# Speech Recognition Function
def listen_for_audio():
    recognizer = sr.Recognizer()
    mic = sr.Microphone()
    recognizer.dynamic_energy_threshold = False
    recognizer.energy_threshold = 400

    with mic as source:
        recognizer.adjust_for_ambient_noise(source, duration=0.5)
        print("Listening for your query...")
        audio = recognizer.listen(source, timeout=30, phrase_time_limit=30)
    
    try:
        request = recognizer.recognize_google(audio, language="en-EN")
        return request
    except Exception as e:
        print("Error recognizing speech:", e)
        return None

# Main Function
def main():
    choice = input("Choose input method: (1) Audio (2) Text\n")
    
    if choice == "1":
        while True:
            print("Please speak your query:")
            query = listen_for_audio()
            if query:
                print(f"You: {query}")
                append2log(f"You: {query}")
                response = call_rag_agent(query)
                print(f"AI: {response}")
                speak_text(response.replace("*", ""))
                append2log(f"AI: {response}")
            else:
                print("Sorry, I didn't catch that. Please try again.")
            # Check for exit keywords
            if query.lower() in ["that's all", "bye", "goodbye", "exit"]:
                print("Exiting... Goodbye!")
                append2log("Exiting... Goodbye!")
                break
                
    elif choice == "2":
        while True:
            query = input("Please type your query: ")
            if query.lower() == "exit":
                print("Exiting...")
                break
            append2log(f"You: {query}")

            response = call_rag_agent(query)
            print(f"AI: {response}")
            append2log(f"AI: {response}")
    else:
        print("Invalid choice. Please restart and select a valid option.")

if __name__ == "__main__":
    main()