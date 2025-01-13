import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

class ApiService {
  final String baseUrl;

  ApiService({required this.baseUrl});

  Future<String> getResponseFromApi(String query) async {
    // Get the current user's UID from Firebase Authentication
    User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      throw Exception('No user is currently signed in');
    }

    String userId = currentUser.uid;  // Get the UID of the current user

    final response = await http.post(
      Uri.parse('$baseUrl/query'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'query': query,
        'user_id': userId,  // Send the user ID in the request
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
