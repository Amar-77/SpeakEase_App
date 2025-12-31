import 'package:flutter_dotenv/flutter_dotenv.dart'; // Import this
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'dart:convert';

class ElevenLabsService {
  // Pull key from .env file
  final String _apiKey = dotenv.get('ELEVEN_LABS_API_KEY', fallback: '');
  final String _voiceId = "21m00Tcm4TlvDq8ikWAM"; 
  final AudioPlayer _audioPlayer = AudioPlayer();

  Future<void> speak(String text) async {
    if (_apiKey.isEmpty) {
      print("Error: API Key is missing from .env file");
      return;
    }

    final url = Uri.parse('https://api.elevenlabs.io/v1/text-to-speech/$_voiceId');

    final response = await http.post(
      url,
      headers: {
        'xi-api-key': _apiKey,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        "text": text,
        "model_id": "eleven_multilingual_v2",
        "voice_settings": {"stability": 0.5, "similarity_boost": 0.5}
      }),
    );

    if (response.statusCode == 200) {
      await _audioPlayer.play(BytesSource(response.bodyBytes));
    }
  }
}