# config.py
import os
from dotenv import load_dotenv
from datetime import date
import firebase_admin
from firebase_admin import credentials, firestore
import google.generativeai as genai
from pygame import mixer

# ---------------------- Environment & Firebase Setup ----------------------
today = str(date.today())

dotenv_path = os.path.join(os.path.dirname(__file__), '.env')
load_dotenv(dotenv_path)
api_key = os.environ.get("GOOGLE_API_KEY")
genai.configure(api_key=api_key)

cred = credentials.Certificate("serviceAccountKey.json")
firebase_admin.initialize_app(cred)
db = firestore.client()

# Initialize audio mixer
mixer.init()

# ---------------------- Constants ----------------------
PERSIST_DIRECTORY = 'db'
BATCH_SIZE = 5000
JSON_FILE_PATH = "Nutrition Data/usda_food_data.json"
