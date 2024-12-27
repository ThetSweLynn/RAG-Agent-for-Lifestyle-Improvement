import 'dart:io';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';

class VoiceChatHelper {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final String baseUrl;
  bool _isRecorderInitialized = false;

  VoiceChatHelper({required this.baseUrl});

  // Check microphone permission, with mock handling for development
  Future<bool> checkPermission({bool mock = false}) async {
    if (mock || Platform.isIOS) {
      // Mock permission for testing or if running on iOS Simulator
      print("Mocking microphone permission as granted.");
      return true;
    }

    final status = await Permission.microphone.status;
    return status.isGranted;
  }

  // Request microphone permission, with fallback for mock development
  Future<bool> requestPermission({bool mock = false}) async {
    if (mock || Platform.isIOS) {
      // Mock permission request as granted
      print("Mocking microphone permission request as granted.");
      return true;
    }

    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  // Initialize the recorder and handle permissions
  Future<void> initRecorder({bool mock = false}) async {
    if (!await checkPermission(mock: mock)) {
      if (!await requestPermission(mock: mock)) {
        throw 'Microphone permission not granted. Please enable it in settings.';
      }
    }

    if (!_isRecorderInitialized) {
      await _recorder.openRecorder();
      _isRecorderInitialized = true;
      print('Recorder initialized');
    }
  }

  // Start recording audio
  Future<void> startRecording({bool mock = false}) async {
    if (!_isRecorderInitialized) {
      await initRecorder(mock: mock);
    }

    if (!await checkPermission(mock: mock)) {
      throw 'Microphone permission not granted';
    }

    try {
      await _recorder.startRecorder(toFile: 'temp_audio.wav');
      print('Recording started: temp_audio.wav');
    } catch (e) {
      throw 'Error starting recorder: $e';
    }
  }

  // Stop recording, send the audio file, and get the response
  Future<String?> stopRecordingAndSend({bool mock = false}) async {
    if (!_isRecorderInitialized || !_recorder.isRecording) {
      throw 'Recorder is not recording';
    }

    final path = await _recorder.stopRecorder();
    if (path == null) throw 'No audio file generated';

    final file = File(path);

    try {
      if (mock) {
        print("Mocking server response for testing.");
        return "Mocked server response: Success!";
      }

      final uri = Uri.parse('$baseUrl/audio_query');
      final request = http.MultipartRequest('POST', uri);
      request.files.add(await http.MultipartFile.fromPath('audio', file.path));

      print('Sending audio to $uri');
      final response = await request.send();
      if (response.statusCode == 200) {
        return await response.stream.bytesToString();
      } else {
        throw 'Server error: ${response.statusCode}';
      }
    } catch (e) {
      throw 'Error processing audio: $e';
    } finally {
      if (await file.exists()) {
        await file.delete();
        print('Temporary audio file deleted');
      }
    }
  }

  // Dispose of the recorder
  Future<void> dispose() async {
    if (_isRecorderInitialized) {
      await _recorder.closeRecorder();
      _isRecorderInitialized = false;
      print('Recorder disposed');
    }
  }
}
