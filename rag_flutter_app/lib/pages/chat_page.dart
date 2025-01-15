import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/api_service.dart';
import 'voice_chat_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_page.dart';

// Dummy pages
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: const Center(child: Text('Profile Page (Dummy)')),
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: const Center(child: Text('Settings Page (Dummy)')),
    );
  }
}

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _controller = TextEditingController();
  final ApiService apiService = ApiService(baseUrl: 'http://127.0.0.1:5000');
  final List<Map<String, String>> _messages = [];

  // User data variables
  String _heartRate = '';
  String _steps = '';
  String _weight = '';

  // Fetch biometric data from Firestore
  Future<void> _getBiometricData() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw 'No user is logged in';
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid) // Use the logged-in user's UID
          .get();

      if (userDoc.exists) {
        setState(() {
          _heartRate = userDoc.data()?['heart_rate']?.toString() ?? 'N/A';
          _steps = userDoc.data()?['steps']?.toString() ?? 'N/A';
          _weight = userDoc.data()?['weight']?.toString() ?? 'N/A';
        });
      } else {
        setState(() {
          _heartRate = 'N/A';
          _steps = 'N/A';
          _weight = 'N/A';
        });
      }
    } catch (e) {
      setState(() {
        _heartRate = 'Error';
        _steps = 'Error';
        _weight = 'Error';
      });
      debugPrint('Error fetching biometric data: $e');
    }
  }

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
  void initState() {
    super.initState();
    // Fetch the biometric data when the page loads
    _getBiometricData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite, color: Colors.red, size: 20),
            const SizedBox(width: 5),
            Text(_heartRate, style: const TextStyle(fontSize: 12, color: Colors.black)),
            const SizedBox(width: 50),
            Icon(Icons.directions_walk, color: Colors.blue, size: 20),
            const SizedBox(width: 5),
            Text(_steps, style: const TextStyle(fontSize: 12, color: Colors.black)),
            const SizedBox(width: 50),
            Icon(Icons.scale, color: Colors.green, size: 20),
            const SizedBox(width: 5),
            Text('$_weight lbs', style: const TextStyle(fontSize: 12, color: Colors.black)),
          ],
        ),
       actions: [
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert), // Vertical three dots icon
          onSelected: (value) {
            switch (value) {
              case 'Profile':
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ProfilePage()),
                );
                break;
              case 'Settings':
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SettingsPage()),
                );
                break;
              case 'Logout':
                FirebaseAuth.instance.signOut();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                );
                break;
            }
          },
          itemBuilder: (BuildContext context) {
            return {'Profile', 'Settings', 'Logout'}.map((String choice) {
              IconData icon;
              Color iconColor = const Color(0xFF008080);
              switch (choice) {
                case 'Profile':
                  icon = Icons.account_circle;
                  iconColor = iconColor;
                  break;
                case 'Settings':
                  icon = Icons.settings;
                  iconColor = iconColor;
                  break;
                case 'Logout':
                  icon = Icons.exit_to_app;
                  iconColor = Colors.red;
                  break;
                default:
                  icon = Icons.help;
              }

              return PopupMenuItem<String>(
                value: choice,
                padding: EdgeInsets.zero, // Remove any padding to prevent spacing
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Wrapping CircleAvatar with a Container for the shadow effect
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3), // Shadow color
                            blurRadius: 10.0, // Blurry effect
                            spreadRadius: 1.0, // Spread of the shadow
                            offset: Offset(3, 3), // Position of the shadow
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        backgroundColor: Colors.grey[200], // Set a color if needed
                        radius: 20,
                        child: Icon(icon, color: iconColor),
                      ),
                    ),
                  ],
                ),
              );
            }).toList();
          },
          color: Colors.transparent, // Make the background of the popup transparent
          elevation: 0, // Remove the shadow effect of the menu
          offset: const Offset(30, 30),
        ),
      ],
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
                final isVoiceChat = message["source"] == "voice_chat";

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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          message["text"] ?? "",
                          style: TextStyle(
                            color: isUser ? Colors.white : Colors.black,
                            fontSize: 16,
                            fontStyle: isVoiceChat ? FontStyle.italic : FontStyle.normal,
                          ),
                          softWrap: true,
                        ),
                        if (isVoiceChat)
                          Padding(
                            padding: const EdgeInsets.only(right: 8.0, top: 4.0),
                            child: Icon(Icons.mic, size: 16, color: isUser ? Colors.white : Colors.black),
                          ),
                      ],
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
                    width: 30,
                    height: 30,
                  ),
                  onPressed: () async {
                    // Navigate to VoiceChatScreen and get any new messages
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => VoiceChatScreen(
                          onNewMessage: (message) {
                            setState(() {
                              _messages.add({...message, "source": "voice_chat"});
                            });
                          },
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
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
                const SizedBox(width: 20),
                CircleAvatar(
                  backgroundColor: const Color(0xFF008080),
                  radius: 24,
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
