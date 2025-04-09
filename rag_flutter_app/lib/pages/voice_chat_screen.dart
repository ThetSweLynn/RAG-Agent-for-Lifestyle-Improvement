import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '/services/globals.dart'; // Import the shared isDarkMode variable
import 'package:rag_flutter_app/services/api_service.dart';

class VoiceChatScreen extends StatefulWidget {
  final Function(Map<String, String>)? onNewMessage;

  const VoiceChatScreen({super.key, this.onNewMessage});

  @override
  _VoiceChatScreenState createState() => _VoiceChatScreenState();
}

class _VoiceChatScreenState extends State<VoiceChatScreen> with SingleTickerProviderStateMixin {
  late stt.SpeechToText _speechToText;
  late FlutterTts _flutterTts;
  late ApiService _apiService;
  late AnimationController _animationController;

  bool _isListening = false;
  String _transcription = "";
  String _response = "";
  String _displayText = "Tap the mic to speak...";
  final List<Map<String, String>> _conversation = [];
  String _currentChunk = ""; // Tracks the currently displayed chunk of text

  @override
  void initState() {
    super.initState();
    _speechToText = stt.SpeechToText();
    _flutterTts = FlutterTts();
    _apiService = ApiService();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _initializeSpeech();

    // Ensure the initial display text is set
    setState(() {
      _displayText = "Tap the mic to start speaking...";
    });
  }

  @override
  void dispose() {
    _speechToText.stop();
    _flutterTts.stop();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _initializeSpeech() async {
    bool available = await _speechToText.initialize();
    if (!available) {
      setState(() {
        _displayText = "Speech recognition is not available.";
      });
    }
  }

  void _startListening() async {
    if (!_isListening) {
      setState(() {
        _isListening = true;
        _displayText = "Listening...";
      });
      _animationController.repeat();

      await _speechToText.listen(onResult: (result) {
        if (_isListening) {
          setState(() {
            _transcription = result.recognizedWords;
            _displayText = _transcription;
          });
        }
      });
    }
  }

  void _stopListening() async {
    if (_isListening) {
      await _speechToText.stop();
      setState(() {
        _isListening = false;
      });

      if (_transcription.isNotEmpty) {
        _addToConversation("user", _transcription);
        setState(() {
          _displayText = "Processing...";
        });
        await _getResponseFromApi(_transcription);
      } else {
        setState(() {
          _displayText = "No speech detected.";
        });
      }
      _animationController.stop();
      _animationController.reset();
    }
  }

  Future<void> _getResponseFromApi(String query) async {
    setState(() {
      _displayText = "Processing...";
    });

    await Future.delayed(const Duration(milliseconds: 100));

    try {
      String apiResponse = await _apiService.getResponseFromApi(query, "true");

      setState(() {
        _response = apiResponse;
        _displayText = _response;
      });

      _addToConversation("bot", apiResponse);
      await _speak(apiResponse);
    } catch (e) {
      setState(() {
        _displayText = "Error: $e";
      });
    }
  }

  Future<void> _speak(String text) async {
    String sanitizedText = _removeEmojis(text);
    List<String> chunks = _splitTextIntoChunks(sanitizedText, 200);
    for (String chunk in chunks) {
      setState(() {
        _currentChunk = chunk;
      });
      await _flutterTts.speak(chunk);
      await _flutterTts.awaitSpeakCompletion(true);
    }
    setState(() {
      _currentChunk = "";
      _displayText = "Tap the mic to speak";
    });
  }

  void _addToConversation(String sender, String text) {
    final message = {"sender": sender, "text": text};
    setState(() {
      _conversation.add(message);
    });
    widget.onNewMessage?.call(message);
  }

  List<String> _splitTextIntoChunks(String text, int chunkSize) {
    List<String> chunks = [];
    int index = 0;

    while (index < text.length) {
      int end = (index + chunkSize).clamp(0, text.length);
      int spaceIndex = text.lastIndexOf(' ', end);

      if (spaceIndex != -1 && spaceIndex > index) {
        chunks.add(text.substring(index, spaceIndex));
        index = spaceIndex + 1;
      } else {
        chunks.add(text.substring(index, end));
        index = end;
      }
    }

    return chunks;
  }

  String _removeEmojis(String text) {
    final emojiRegex = RegExp(
      r'[\u{1F600}-\u{1F64F}]|' // Emoticons
      r'[\u{1F300}-\u{1F5FF}]|' // Miscellaneous Symbols and Pictographs
      r'[\u{1F680}-\u{1F6FF}]|' // Transport and Map Symbols
      r'[\u{1F700}-\u{1F77F}]|' // Alchemical Symbols
      r'[\u{1F780}-\u{1F7FF}]|' // Geometric Shapes Extended
      r'[\u{1F800}-\u{1F8FF}]|' // Supplemental Arrows-C
      r'[\u{1F900}-\u{1F9FF}]|' // Supplemental Symbols and Pictographs
      r'[\u{1FA00}-\u{1FA6F}]|' // Chess Symbols
      r'[\u{1FA70}-\u{1FAFF}]|' // Symbols and Pictographs Extended-A
      r'[\u{2600}-\u{26FF}]|'   // Miscellaneous Symbols
      r'[\u{2700}-\u{27BF}]',   // Dingbats
      unicode: true,
    );
    return text.replaceAll(emojiRegex, '');
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;

    return ValueListenableBuilder<bool>(
      valueListenable: isDarkMode,
      builder: (context, darkMode, child) {
        return Scaffold(
          backgroundColor: darkMode ? Colors.grey[900] : Colors.white,
          appBar: AppBar(
            title: const Text("Voice Chat"),
            backgroundColor: darkMode ? Colors.grey[900] : Colors.transparent,
            iconTheme: IconThemeData(color: darkMode ? Colors.grey : Colors.black),
            titleTextStyle: TextStyle(
              color: darkMode ? Colors.white : Colors.black,
              fontSize: screenWidth * 0.055, // 5.5% of screen width
              fontWeight: FontWeight.w400,
            ),
          ),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated Robot Image
                AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _isListening
                            ? Colors.redAccent.withOpacity(0.5)
                            : (darkMode
                                ? Colors.tealAccent.withOpacity(0.5)
                                : const Color(0xFF66B2B2).withOpacity(0.5)),
                        blurRadius: screenWidth * 0.055, // 8% of screen width
                        offset: Offset(0, screenHeight * 0.01), // 1% of screen height
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/robot.jpg',
                      width: screenWidth * 0.6, // 60% of screen width
                      height: screenWidth * 0.6, // 60% of screen width
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                SizedBox(height: screenHeight * 0.05), // 5% of screen height
                // Display Text Container
                Container(
                  width: screenWidth * 0.85, // 85% of screen width
                  height: screenHeight * 0.25, // 25% of screen height
                  padding: EdgeInsets.all(screenWidth * 0.05), // 5% of screen width
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(screenWidth * 0.04), // 4% of screen width
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      _currentChunk.isNotEmpty ? _currentChunk : _displayText,
                      style: TextStyle(
                        fontSize: screenWidth * 0.04, // 4% of screen width
                        fontWeight: FontWeight.w500,
                        color: darkMode ? Colors.white70 : Colors.black,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                SizedBox(height: screenHeight * 0.04), // 4% of screen height
                // Microphone Button
                GestureDetector(
                  onTap: () {
                    if (_isListening) {
                      _stopListening();
                    } else {
                      _startListening();
                    }
                  },
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (_isListening)
                        ...List.generate(3, (index) {
                          return AnimatedBuilder(
                            animation: _animationController,
                            builder: (context, child) {
                              final progress = (_animationController.value + index * 0.33) % 1.0;
                              final scale = 1.0 + progress;
                              final opacity = 1.0 - progress;

                              return Transform.scale(
                                scale: scale,
                                child: Opacity(
                                  opacity: opacity,
                                  child: Container(
                                    width: screenWidth * 0.25, // 25% of screen width
                                    height: screenWidth * 0.25, // 25% of screen width
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.red.withOpacity(0.2),
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        }),
                      CircleAvatar(
                        radius: screenWidth * 0.13, // 13% of screen width
                        backgroundColor: _isListening
                            ? Colors.red
                            : (darkMode ? Colors.grey[700] : const Color(0xFF66B2B2)),
                        child: Icon(
                          Icons.mic,
                          color: Colors.white,
                          size: screenWidth * 0.08, // 8% of screen width
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
