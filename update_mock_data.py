import firebase_admin
from firebase_admin import credentials, firestore
import random
import time

cred = credentials.Certificate("serviceAccountKey.json")
firebase_admin.initialize_app(cred)
db = firestore.client()

def update_mock_data(user_id):
    while True:
        db.collection('users').document(user_id).update({
            'weight': random.randint(80, 200),
            'heart_rate': random.randint(60, 100),
            'steps': random.randint(1000, 10000),
            'calories_burned': random.randint(100, 500),
            'last_updated': firestore.SERVER_TIMESTAMP
        })
        print("Updated mock data")
        time.sleep(30)  # Update every 30 seconds

update_mock_data("user001")
