import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class PracticeApiService {
  static final String _baseUrl =
      dotenv.env['API_URL'] ?? "http://10.0.2.2:8000";

  Future<String> generatePractice({
    required String sentence,
    required String weakArea,
  }) async {
    try {
      final uri = Uri.parse("$_baseUrl/generate-practice/");

      final response = await http.post(
        uri,
        headers: {
          "Content-Type": "application/x-www-form-urlencoded",
        },
        body: {
          "expected_word": weakArea, // This is the mispronounced word
          "score": "50.0",           // Force a low score to ensure AI generates text
        },
      );

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        return decoded['practice_text'] ?? "";
      } else {
        print("Groq API Error: ${response.body}");
        return "";
      }
    } catch (e) {
      print("Practice API Exception: $e");
      return "";
    }
  }
}
