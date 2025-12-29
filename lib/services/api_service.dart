import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/analysis_model.dart'; // Make sure you move your QuickAnalysis/WordAnalysis classes to a separate file, or define them here.

class ApiService {
  Future<Map<String, dynamic>?> analyzeAudio(String filePath, String refText) async {
    try {
      String? baseUrl = dotenv.env['API_URL'];
      if (baseUrl == null) return null;

      var uri = Uri.parse('$baseUrl/analyze/');
      var request = http.MultipartRequest('POST', uri);

      request.files.add(await http.MultipartFile.fromPath('file', filePath));
      request.fields['correct_text'] = refText;

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        print("Server Error: ${response.body}");
        return null;
      }
    } catch (e) {
      print("Connection Error: $e");
      return null;
    }
  }
}