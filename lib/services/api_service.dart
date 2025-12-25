import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/analysis_model.dart';

class ApiService {
  // ⚠️ CHANGE THIS IP depending on where you run the app!
  // Android Emulator: 'http://10.0.2.2:8000/analyze/'
  // Physical Device: 'http://192.168.1.X:8000/analyze/' (Check your PC settings)
  static const String _baseUrl = 'http://10.0.2.2:8000/analyze/';

  Future<AnalysisResponse?> analyzeAudio(String filePath, String correctText) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse(_baseUrl));

      // 1. Add the Audio File
      request.files.add(await http.MultipartFile.fromPath('file', filePath));

      // 2. Add the Text
      request.fields['correct_text'] = correctText;

      // 3. Send
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        // 4. Decode JSON
        var jsonData = json.decode(response.body);
        return AnalysisResponse.fromJson(jsonData);
      } else {
        print("Server Error: ${response.statusCode} - ${response.body}");
        return null;
      }
    } catch (e) {
      print("Connection Error: $e");
      return null;
    }
  }
}