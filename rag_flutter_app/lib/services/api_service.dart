import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

class ApiService {
  static const String baseUrl = "https://rag-agent-for-lifestyle-improvement.onrender.com";

  Future<String> getResponseFromApi(String query, String isWeekly, {String? startDate}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/query'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'query': query,
        'user_id': FirebaseAuth.instance.currentUser?.uid,
        'isWeekly': isWeekly.toString(),
        'start_date': startDate, // Include the start_date parameter
      }),
    );

    if (response.statusCode == 200) {
      // Extract the response data
      final Map<String, dynamic> data = json.decode(response.body);
      return data['response'];  // Assuming 'response' is the field in the response
    } else {
      throw Exception('Failed to get data from API');
    }
  }
}
