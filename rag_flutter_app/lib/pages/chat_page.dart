import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'voice_chat_screen.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _controller = TextEditingController();
  final ApiService apiService = ApiService(baseUrl: 'http://127.0.0.1:5000');

  final List<Map<String, String>> _messages = [];

  Future<void> _sendMessage() async {
    final query = _controller.text;
    if (query.isEmpty) return;

    setState(() {
      _messages.add({"sender": "user", "text": query});
    });

    _controller.clear();

    try {
      final response = await apiService.getResponseFromApi(query);

      setState(() {
        _messages.add({"sender": "bot", "text": response});
      });
    } catch (e) {
      setState(() {
        _messages.add({"sender": "bot", "text": "Error: $e"});
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lifestyle Assistant'),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(8.0),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                final isUser = message["sender"] == "user";

                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: isUser
                        ? const EdgeInsets.only(left: 30, right: 8, top: 10, bottom: 10)
                        : const EdgeInsets.only(left: 8, right: 30, top: 10, bottom: 10),
                    padding: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                      color: isUser
                          ? const Color(0xFF008080)
                          : const Color(0xFFD9D9D9),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft:
                            isUser ? const Radius.circular(16) : const Radius.circular(0),
                        bottomRight:
                            isUser ? const Radius.circular(0) : const Radius.circular(16),
                      ),
                    ),
                    child: Text(
                      message["text"] ?? "",
                      style: TextStyle(
                        color: isUser ? Colors.white : Colors.black,
                        fontSize: 16,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 10.0, right: 15.0, bottom: 35.0),
            child: Row(
              children: [
                IconButton(
                  icon: Image.asset(
                    'assets/voice_chat.png',
                    width: 30, // Adjust the width to fit your design
                    height: 30, // Adjust the height to fit your design
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => VoiceChatScreen()),
                    );
                  },
                ),
                const SizedBox(width: 8), // Add more spacing before text field
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: 'Ask something.....',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 20), // Add more spacing before send button
                CircleAvatar(
                  backgroundColor: const Color(0xFF008080),
                  radius: 24, // Optional: Adjust size of the send button for prominence
                  child: IconButton(
                    icon: const Icon(Icons.arrow_upward, color: Colors.white),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
