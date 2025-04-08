# config.py
import os
from dotenv import load_dotenv
from datetime import date
import firebase_admin
from firebase_admin import credentials, firestore
import google.generativeai as genai

# ---------------------- Environment & Firebase Setup ----------------------
today = str(date.today())

dotenv_path = os.path.join(os.path.dirname(__file__), '.env')
load_dotenv(dotenv_path)
api_key = os.environ.get("GOOGLE_API_KEY")
genai.configure(api_key=api_key)

# Check if running on Render (secret file exists at this path)
render_path = "/etc/secrets/serviceAccountKey.json"
local_path = "serviceAccountKey.json"

if os.path.exists(render_path):
    cred = credentials.Certificate(render_path)
else:
    cred = credentials.Certificate(local_path)

firebase_admin.initialize_app(cred)
db = firestore.client()