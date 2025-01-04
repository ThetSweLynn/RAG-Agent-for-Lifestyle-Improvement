import 'package:flutter/material.dart';
import 'package:rag_flutter_app/services/voice_chat_helper.dart';

class VoiceChatScreen extends StatefulWidget {
  const VoiceChatScreen({super.key});

  @override
  _VoiceChatScreenState createState() => _VoiceChatScreenState();
}

class _VoiceChatScreenState extends State<VoiceChatScreen> {
  final VoiceChatHelper _voiceChatHelper = VoiceChatHelper(baseUrl: 'https://your-api-base-url.com');
  String? _response = "Press and hold the button to speak.";
  bool _isRecording = false;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeVoiceChat();
  }

  // Initialize voice chat with mock permissions
  Future<void> _initializeVoiceChat() async {
    try {
      await _voiceChatHelper.initRecorder(mock: true); // Enable mock mode
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _response = "Error initializing voice chat: $e";
        });
      }
    }
  }

  // Handle recording start
  void _startRecording() async {
    if (!_isInitialized) {
      await _initializeVoiceChat();
    }

    try {
      await _voiceChatHelper.startRecording(mock: true); // Enable mock mode
      setState(() {
        _isRecording = true;
        _response = "Listening...";
      });
    } catch (e) {
      setState(() {
        _response = "Error starting recording: $e";
      });
    }
  }

  // Handle recording stop and send the audio
  void _stopRecording() async {
    try {
      final response = await _voiceChatHelper.stopRecordingAndSend(mock: true); // Enable mock mode
      setState(() {
        _isRecording = false;
        _response = response ?? "No response received.";
      });
    } catch (e) {
      setState(() {
        _isRecording = false;
        _response = "Error stopping recording: $e";
      });
    }
  }

  @override
  void dispose() {
    _voiceChatHelper.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Voice Chat")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                _response ?? "",
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onLongPress: _startRecording,
              onLongPressUp: _stopRecording,
              child: CircleAvatar(
                radius: 60,
                backgroundColor: _isRecording ? Colors.red : const Color(0xFF66B2B2),
                child: Image.asset(
                    'assets/voice_chat.png',
                    width: 60, // Adjust the width to fit your design
                    height: 60, // Adjust the height to fit your design
                  ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
