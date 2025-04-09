from flask import Flask, request, jsonify
from qa_agent import call_rag_agent
from datetime import datetime
import os

app = Flask(__name__)

# Define route for text query
@app.route('/query', methods=['POST'])
def query_rag():
    data = request.get_json()  # Get the JSON data from the request
    user_query = data.get('query', '')  # Extract the query
    user_id = data.get('user_id', '')  # Extract the user ID
    user_isWeekly = data.get('isWeekly', '')  # Extract the isWeekly flag
    start_date_str = data.get('start_date', '')  # Extract the start date (optional)

    # Ensure isWeekly is a boolean
    if isinstance(user_isWeekly, str):
        user_isWeekly = user_isWeekly.lower() == 'true'

    # Parse the start_date if provided
    start_date = None
    if start_date_str:
        try:
            start_date = datetime.strptime(start_date_str, '%Y-%m-%d').date()
        except ValueError:
            return jsonify({"error": "Invalid start_date format. Use YYYY-MM-DD."}), 400

    if not user_query or not user_id:
        return jsonify({"error": "Query, user_id, and isWeekly values are required"}), 400

    # Call RAG agent with the user ID and start_date
    response = call_rag_agent(user_query, user_id, user_isWeekly, start_date)

    return jsonify({"response": response}), 200


if __name__ == '__main__':
    port = int(os.environ.get('PORT', 5001))
    app.run(host='0.0.0.0', port=port, debug=True)