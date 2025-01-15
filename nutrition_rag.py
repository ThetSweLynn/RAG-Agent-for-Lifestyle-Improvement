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
import firebase_admin
from firebase_admin import credentials, firestore

# Initialize Firebase
cred = credentials.Certificate("serviceAccountKey.json")  # Download this file from Firebase Console
firebase_admin.initialize_app(cred)
db = firestore.client()

#Get user biometric data from Firestore
def get_user_biometric_data(user_id):
    try:
        user_doc = db.collection('users').document(user_id).get()
        if user_doc.exists:
            return user_doc.to_dict()  # Returns a dictionary of biometric data
        else:
            return None
    except Exception as e:
        print(f"Error fetching user data: {e}")
        return None

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
    return '\n'.join(wrapped_lines).rstrip('\n')

def process_llm_response(llm_response):
    final_response = wrap_text_preserve_newlines(llm_response.get('result', 'No response generated.'))
    
    source_info = "\n\nSources:\n"
    if 'source_documents' in llm_response and llm_response["source_documents"]:
        relevant_sources = [
            source.metadata.get('source', 'Unknown Source')
            for source in llm_response["source_documents"]
            if source.metadata.get('relevance_score', 0) > 0.5
        ]
        if relevant_sources:
            for i, source_name in enumerate(relevant_sources):
                source_info += f"{i + 1}. {source_name}\n"
        else:
            source_info += "No relevant sources found.\n"
    else:
        source_info += "No sources found.\n"

    final_response_with_sources = final_response + source_info

    return final_response_with_sources

# RAG Agent Function
# New Method: Answer Questions Without Sources
def call_rag_agent(query, userId):  
    
    #Get knowledge base
    try:
        retrieved_docs = retriever.invoke(query)
    except Exception as e:
        print(f"Error during retrieval: {e}")
        retrieved_docs = []

    relevant_docs = []
    for doc in retrieved_docs:
        if query.lower() in doc.page_content.lower() or len(doc.page_content.strip()) > 50:
            relevant_docs.append(doc)

    if relevant_docs:
        retrieved_text = "\n".join([doc.page_content for doc in relevant_docs[:3]])
        context_info = f"Here is some information from your Nutrition Data PDFs that might help:\n{retrieved_text}\n"
    else:
        context_info = "No relevant information found in Nutrition Data PDFs.\n"

    #Get conversation history
    conversation_history = memory.get_history()

    custom_prompt = (
        "You are an AI lfestyle improvement assistant with expertise in dietary recommendations and workout planning. "
        "Answer user queries concisely, providing evidence-based insights. "
        "Keep the answers brief, with a maximum of 6 lines. "
        "Avoid speculative statements."
    )
    
    #Get user biometric data
    biometric_data = get_user_biometric_data(userId)
    
    if biometric_data:
        biometric_info = (
            f"User's Biometric Data:\n"
            f"- Name: {biometric_data.get('name', 'N/A')} \n"
            f"- Age: {biometric_data.get('age', 'N/A')} years\n"
            f"- Weight: {biometric_data.get('weight', 'N/A')} lbs\n"
            f"- Heart Rate: {biometric_data.get('heart_rate', 'N/A')} bpm\n"
            f"- Steps: {biometric_data.get('steps', 'N/A')}\n"
            f"- Calories Burned: {biometric_data.get('calories_burned', 'N/A')} kcal\n"
            f"- Last Updated: {biometric_data.get('last_updated', 'N/A')}\n"
        )
    else:
        biometric_info = "No biometric data available for this user.\n"

    prompt = (
        f"{custom_prompt}\n"
        f"{context_info}\n"
        f"{biometric_info}\n"
        f"Previous Conversation:\n{conversation_history}\n"
        f"User Query: {query}\nAI:"
    )

    response = qa_chain.invoke(prompt)

    # Exclude sources from the response
    final_response = response['result'].rstrip('\n') #wrap_text_preserve_newlines(response['result'])
    memory.append_to_history(query, final_response)

    return final_response

"""
def call_rag_agent_with_sources(query):
    try:
        retrieved_docs = retriever.invoke(query)
    except Exception as e:
        print(f"Error during retrieval: {e}")
        retrieved_docs = []

    relevant_docs = []
    for doc in retrieved_docs:
        if query.lower() in doc.page_content.lower() or len(doc.page_content.strip()) > 50:
            relevant_docs.append(doc)

    if relevant_docs:
        retrieved_text = "\n".join([doc.page_content for doc in relevant_docs[:3]])
        context_info = f"Here is some information from your Nutrition Data PDFs that might help:\n{retrieved_text}\n"
        include_sources = True
    else:
        context_info = "No relevant information found in Nutrition Data PDFs.\n"
        include_sources = False

    conversation_history = memory.get_history()

    custom_prompt = (
        "You are an AI nutritionist with expertise in dietary recommendations and nutritional science. "
        "Answer user queries concisely, providing evidence-based insights. "
        "Keep the answers brief, with a maximum of 6 lines. "
        "Cite sources where relevant and avoid speculative statements."
    )
    
    prompt = (
        f"{custom_prompt}\n"
        f"{context_info}\n"
        f"Previous Conversation:\n{conversation_history}\n"
        f"User Query: {query}\nAI:"
    )

    response = qa_chain.invoke(prompt)

    final_response = wrap_text_preserve_newlines(response['result'])
    if include_sources and 'source_documents' in response and response["source_documents"]:
        source_info = "\n\nSources:\n"
        for i, source in enumerate(response["source_documents"]):
            source_name = source.metadata.get('source', 'Unknown Source')
            source_info += f"{i + 1}. {source_name}\n"
        final_response += source_info

    memory.append_to_history(query, final_response)

    return final_response
""" 

# Text-to-Speech Function
def speak_text(text):
    try:
        cleaned_text = text.replace('\n', ' ').strip()
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
