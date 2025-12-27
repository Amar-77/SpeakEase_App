// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:file_picker/file_picker.dart';
// import 'package:http/http.dart' as http;
// import 'package:path_provider/path_provider.dart';
// // import 'package:permission_handler/permission_handler.dart';
// import 'package:record/record.dart';
// import 'dart:convert';
// // import 'package:flutter_dotenv/flutter_dotenv.dart';


// // --- 1. DATA MODELS ---
// class QuickAnalysis {
//   final double overallScore;
//   final double fluency;
//   final double pronunciation;
//   final double wpm;
//   final String transcription;
//   final List<WordAnalysis> wordAnalysis;

//   QuickAnalysis({
//     required this.overallScore,
//     required this.fluency,
//     required this.pronunciation,
//     required this.wpm,
//     required this.transcription,
//     required this.wordAnalysis,
//   });

//   factory QuickAnalysis.fromJson(Map<String, dynamic> json) {
//     var scores = json['quality_scores'] ?? {};
//     var metrics = json['transcription_metrics'] ?? {};

//     return QuickAnalysis(
//       overallScore: double.tryParse(scores['overall_score'].toString()) ?? 0.0,
//       fluency: double.tryParse(scores['fluency'].toString()) ?? 0.0,
//       pronunciation: double.tryParse(scores['pronunciation'].toString()) ?? 0.0,
//       wpm: double.tryParse(metrics['words_per_minute'].toString()) ?? 0.0,
//       transcription: json['full_transcription'] ?? "",
//       wordAnalysis: (json['word_analysis'] as List?)
//           ?.map((x) => WordAnalysis.fromJson(x))
//           .toList() ?? [],
//     );
//   }
// }

// class WordAnalysis {
//   final String text;
//   final String color;
//   final String status;

//   WordAnalysis({required this.text, required this.color, required this.status});

//   factory WordAnalysis.fromJson(Map<String, dynamic> json) {
//     return WordAnalysis(
//       text: json['text'] ?? '',
//       color: json['color'] ?? 'black',
//       status: json['status'] ?? 'unknown',
//     );
//   }
// }

// // --- 2. SCREEN UI ---
// class TestModelScreen extends StatefulWidget {
//   const TestModelScreen({super.key});

//   @override
//   State<TestModelScreen> createState() => _TestModelScreenState();
// }

// class _TestModelScreenState extends State<TestModelScreen> {
//   final TextEditingController _textController = TextEditingController(text: "The quick brown fox jumps over the lazy dog");
//   final AudioRecorder _audioRecorder = AudioRecorder();

//   String? _audioPath;
//   bool _isRecording = false;
//   bool _isLoading = false;
//   String _statusMessage = "Ready to test.";
//   QuickAnalysis? _result;

//   @override
//   void dispose() {
//     _textController.dispose();
//     _audioRecorder.dispose();
//     super.dispose();
//   }

//   // --- RECORDING LOGIC ---
//   Future<void> _startRecording() async {
//     try {
//       if (await _audioRecorder.hasPermission()) {
//         final Directory appDir = await getApplicationDocumentsDirectory();
//         final String filePath = '${appDir.path}/test_recording.m4a';
//         await _audioRecorder.start(const RecordConfig(), path: filePath);
//         setState(() { _isRecording = true; _statusMessage = "Recording... Speak now!"; _result = null; });
//       } else {
//         setState(() => _statusMessage = "Microphone permission denied.");
//       }
//     } catch (e) {
//       setState(() => _statusMessage = "Error starting record: $e");
//     }
//   }

//   Future<void> _stopRecording() async {
//     final path = await _audioRecorder.stop();
//     setState(() { _isRecording = false; _audioPath = path; _statusMessage = "Recording saved!"; });
//   }

//   Future<void> _pickFile() async {
//     FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.audio);
//     if (result != null && result.files.single.path != null) {
//       setState(() { _audioPath = result.files.single.path; _statusMessage = "File selected: ${result.files.single.name}"; _result = null; });
//     }
//   }

//   // --- API LOGIC ---
//   Future<void> _analyze() async {
//     if (_audioPath == null) {
//       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No Audio Selected!")));
//       return;
//     }
//     setState(() { _isLoading = true; _statusMessage = "Analyzing..."; });

//     try {
//       // ⚠️ IP ADDRESS: Use 10.0.2.2 for Emulator, or your PC's LAN IP (e.g. 192.168.1.X) for real device
//       var uri = Uri.parse('http://192.168.1.35:8000/analyze/');

//       var request = http.MultipartRequest('POST', uri);
//       request.files.add(await http.MultipartFile.fromPath('file', _audioPath!));
//       request.fields['correct_text'] = _textController.text;

//       var streamedResponse = await request.send();
//       var response = await http.Response.fromStream(streamedResponse);

//       if (response.statusCode == 200) {
//         var data = json.decode(response.body);
//         setState(() { _result = QuickAnalysis.fromJson(data); _statusMessage = "Success! ✅"; });
//       } else {
//         setState(() => _statusMessage = "Server Error: ${response.statusCode}");
//       }
//     } catch (e) {
//       setState(() => _statusMessage = "Connection Error: $e");
//     } finally {
//       setState(() => _isLoading = false);
//     }
//   }

//   // --- 3. THE RICH TEXT BUILDER (Color Logic) ---
//   Widget _buildRichTextTranscription(List<WordAnalysis> words) {
//     if (words.isEmpty) return const Text("No detailed analysis available.");

//     return RichText(
//       text: TextSpan(
//         style: const TextStyle(fontSize: 18, height: 1.5, color: Colors.black),
//         children: words.map((word) {
//           Color textColor = Colors.black;
//           FontWeight fontWeight = FontWeight.normal;
//           TextDecoration decoration = TextDecoration.none;
//           Color? backgroundColor;

//           switch (word.color) {
//             case 'green': // Perfect
//               textColor = Colors.green.shade700;
//               fontWeight = FontWeight.bold;
//               break;
//             case 'red': // Mistake
//               textColor = Colors.red.shade700;
//               backgroundColor = Colors.red.shade50;
//               fontWeight = FontWeight.w600;
//               break;
//             case 'gray': // Omitted
//               textColor = Colors.grey;
//               decoration = TextDecoration.lineThrough;
//               break;
//             case 'black': // Correct
//             default:
//               textColor = Colors.black87;
//           }

//           return TextSpan(
//             text: "${word.text} ",
//             style: TextStyle(
//               color: textColor,
//               fontWeight: fontWeight,
//               backgroundColor: backgroundColor,
//               decoration: decoration,
//             ),
//           );
//         }).toList(),
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text("AI Speech Analysis"), backgroundColor: Colors.teal),
//       body: SingleChildScrollView(
//         padding: const EdgeInsets.all(20),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.stretch,
//           children: [
//             const Text("1. Enter Reference Text:", style: TextStyle(fontWeight: FontWeight.bold)),
//             const SizedBox(height: 5),
//             TextField(controller: _textController, maxLines: 2, decoration: const InputDecoration(border: OutlineInputBorder())),
//             const SizedBox(height: 20),

//             const Text("2. Provide Audio:", style: TextStyle(fontWeight: FontWeight.bold)),
//             const SizedBox(height: 10),
//             Row(
//               children: [
//                 Expanded(
//                   child: ElevatedButton.icon(
//                     onPressed: _isRecording ? _stopRecording : _startRecording,
//                     style: ElevatedButton.styleFrom(backgroundColor: _isRecording ? Colors.red : Colors.orange, foregroundColor: Colors.white),
//                     icon: Icon(_isRecording ? Icons.stop : Icons.mic),
//                     label: Text(_isRecording ? "Stop" : "Record"),
//                   ),
//                 ),
//                 const SizedBox(width: 10),
//                 Expanded(
//                   child: ElevatedButton.icon(
//                     onPressed: _pickFile,
//                     style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
//                     icon: const Icon(Icons.upload_file),
//                     label: const Text("Upload File"),
//                   ),
//                 ),
//               ],
//             ),
//             const SizedBox(height: 10),
//             Center(child: Text(_statusMessage, style: TextStyle(color: Colors.grey.shade700, fontStyle: FontStyle.italic))),

//             const SizedBox(height: 20),
//             ElevatedButton(
//               onPressed: _isLoading ? null : _analyze,
//               style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(15), backgroundColor: Colors.teal, foregroundColor: Colors.white),
//               child: _isLoading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white)) : const Text("🔍 ANALYZE SPEECH", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
//             ),

//             const SizedBox(height: 30),

//             // --- 4. RESULTS DISPLAY ---
//             if (_result != null) ...[
//               const Divider(thickness: 2),
//               const SizedBox(height: 10),

//               // SCORE CIRCLE (FIXED)
//               Center(
//                 child: Column(
//                   children: [
//                     Stack(
//                       alignment: Alignment.center,
//                       children: [
//                         SizedBox(
//                           height: 120,
//                           width: 120,
//                           child: CircularProgressIndicator(
//                             value: _result!.overallScore / 100,
//                             strokeWidth: 10,
//                             backgroundColor: Colors.grey.shade200,
//                             color: Colors.teal,
//                           ),
//                         ),
//                         Text("${_result!.overallScore.toStringAsFixed(0)}%", style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.teal)),
//                       ],
//                     ),
//                     const SizedBox(height: 10),
//                     const Text("Overall Score", style: TextStyle(fontWeight: FontWeight.bold)),
//                   ],
//                 ),
//               ),
//               const SizedBox(height: 20),

//               Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceAround,
//                 children: [
//                   _buildMetricBox("Fluency", _result!.fluency),
//                   _buildMetricBox("Pronunciation", _result!.pronunciation),
//                   _buildMetricBox("Speed (WPM)", _result!.wpm),
//                 ],
//               ),

//               const SizedBox(height: 30),
//               const Text("📝 Color-Coded Feedback:", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
//               const SizedBox(height: 10),

//               Container(
//                 padding: const EdgeInsets.all(15),
//                 decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade300), boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 10)]),
//                 child: _buildRichTextTranscription(_result!.wordAnalysis),
//               ),

//               const SizedBox(height: 10),
//               const Wrap(
//                 spacing: 15,
//                 children: [
//                   Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.circle, color: Colors.green, size: 12), SizedBox(width: 5), Text("Perfect")]),
//                   Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.circle, color: Colors.red, size: 12), SizedBox(width: 5), Text("Mistake")]),
//                   Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.circle, color: Colors.grey, size: 12), SizedBox(width: 5), Text("Omitted")]),
//                 ],
//               )
//             ]
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildMetricBox(String label, double value) {
//     return Column(
//       children: [
//         Text(value.toStringAsFixed(1), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
//         Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
//       ],
//     );
//   }
// }
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // IMPORT THIS

// --- 1. DATA MODELS ---
class QuickAnalysis {
  final double overallScore;
  final double fluency;
  final double pronunciation;
  final double wpm;
  final String transcription;
  final List<WordAnalysis> wordAnalysis;

  QuickAnalysis({
    required this.overallScore,
    required this.fluency,
    required this.pronunciation,
    required this.wpm,
    required this.transcription,
    required this.wordAnalysis,
  });

  factory QuickAnalysis.fromJson(Map<String, dynamic> json) {
    var scores = json['quality_scores'] ?? {};
    var metrics = json['transcription_metrics'] ?? {};

    return QuickAnalysis(
      overallScore: double.tryParse(scores['overall_score'].toString()) ?? 0.0,
      fluency: double.tryParse(scores['fluency'].toString()) ?? 0.0,
      pronunciation: double.tryParse(scores['pronunciation'].toString()) ?? 0.0,
      wpm: double.tryParse(metrics['words_per_minute'].toString()) ?? 0.0,
      transcription: json['full_transcription'] ?? "",
      wordAnalysis: (json['word_analysis'] as List?)
          ?.map((x) => WordAnalysis.fromJson(x))
          .toList() ?? [],
    );
  }
}

class WordAnalysis {
  final String text;
  final String color;
  final String status;

  WordAnalysis({required this.text, required this.color, required this.status});

  factory WordAnalysis.fromJson(Map<String, dynamic> json) {
    return WordAnalysis(
      text: json['text'] ?? '',
      color: json['color'] ?? 'black',
      status: json['status'] ?? 'unknown',
    );
  }
}

// --- 2. SCREEN UI ---
class TestModelScreen extends StatefulWidget {
  const TestModelScreen({super.key});

  @override
  State<TestModelScreen> createState() => _TestModelScreenState();
}

class _TestModelScreenState extends State<TestModelScreen> {
  final TextEditingController _textController = TextEditingController(text: "The quick brown fox jumps over the lazy dog");
  final AudioRecorder _audioRecorder = AudioRecorder();

  String? _audioPath;
  bool _isRecording = false;
  bool _isLoading = false;
  String _statusMessage = "Ready to test.";
  QuickAnalysis? _result;

  @override
  void dispose() {
    _textController.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  // --- RECORDING LOGIC ---
  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final Directory appDir = await getApplicationDocumentsDirectory();
        final String filePath = '${appDir.path}/test_recording.m4a';
        await _audioRecorder.start(const RecordConfig(), path: filePath);
        setState(() { _isRecording = true; _statusMessage = "Recording... Speak now!"; _result = null; });
      } else {
        setState(() => _statusMessage = "Microphone permission denied.");
      }
    } catch (e) {
      setState(() => _statusMessage = "Error starting record: $e");
    }
  }

  Future<void> _stopRecording() async {
    final path = await _audioRecorder.stop();
    setState(() { _isRecording = false; _audioPath = path; _statusMessage = "Recording saved!"; });
  }

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.audio);
    if (result != null && result.files.single.path != null) {
      setState(() { _audioPath = result.files.single.path; _statusMessage = "File selected: ${result.files.single.name}"; _result = null; });
    }
  }

  // --- API LOGIC ---
  Future<void> _analyze() async {
    if (_audioPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No Audio Selected!")));
      return;
    }
    setState(() { _isLoading = true; _statusMessage = "Analyzing..."; });

    try {
      // 1. GET URL FROM ENV FILE
      print("API_URL => ${dotenv.env['API_URL']}");

      String? baseUrl = dotenv.env['API_URL'];

      if (baseUrl == null || baseUrl.isEmpty) {
        setState(() => _statusMessage = "Error: API_URL not found in .env file");
        _isLoading = false;
        return;
      }

      // 2. Build the full endpoint
      var uri = Uri.parse('$baseUrl/analyze/');

      var request = http.MultipartRequest('POST', uri);
      request.files.add(await http.MultipartFile.fromPath('file', _audioPath!));
      request.fields['correct_text'] = _textController.text;

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        var data = json.decode(response.body);
        setState(() { _result = QuickAnalysis.fromJson(data); _statusMessage = "Success! ✅"; });
      } else {
        setState(() => _statusMessage = "Server Error: ${response.statusCode}");
      }
    } catch (e) {
      setState(() => _statusMessage = "Connection Error: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // --- 3. THE RICH TEXT BUILDER (Color Logic) ---
  Widget _buildRichTextTranscription(List<WordAnalysis> words) {
    if (words.isEmpty) return const Text("No detailed analysis available.");

    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 18, height: 1.5, color: Colors.black),
        children: words.map((word) {
          Color textColor = Colors.black;
          FontWeight fontWeight = FontWeight.normal;
          TextDecoration decoration = TextDecoration.none;
          Color? backgroundColor;

          switch (word.color) {
            case 'green': // Perfect
              textColor = Colors.green.shade700;
              fontWeight = FontWeight.bold;
              break;
            case 'red': // Mistake
              textColor = Colors.red.shade700;
              backgroundColor = Colors.red.shade50;
              fontWeight = FontWeight.w600;
              break;
            case 'gray': // Omitted
              textColor = Colors.grey;
              decoration = TextDecoration.lineThrough;
              break;
            case 'black': // Correct
            default:
              textColor = Colors.black87;
          }

          return TextSpan(
            text: "${word.text} ",
            style: TextStyle(
              color: textColor,
              fontWeight: fontWeight,
              backgroundColor: backgroundColor,
              decoration: decoration,
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("AI Speech Analysis"), backgroundColor: Colors.teal),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text("1. Enter Reference Text:", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 5),
            TextField(controller: _textController, maxLines: 2, decoration: const InputDecoration(border: OutlineInputBorder())),
            const SizedBox(height: 20),

            const Text("2. Provide Audio:", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isRecording ? _stopRecording : _startRecording,
                    style: ElevatedButton.styleFrom(backgroundColor: _isRecording ? Colors.red : Colors.orange, foregroundColor: Colors.white),
                    icon: Icon(_isRecording ? Icons.stop : Icons.mic),
                    label: Text(_isRecording ? "Stop" : "Record"),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _pickFile,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                    icon: const Icon(Icons.upload_file),
                    label: const Text("Upload File"),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Center(child: Text(_statusMessage, style: TextStyle(color: Colors.grey.shade700, fontStyle: FontStyle.italic))),

            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isLoading ? null : _analyze,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(15), backgroundColor: Colors.teal, foregroundColor: Colors.white),
              child: _isLoading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white)) : const Text("🔍 ANALYZE SPEECH", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),

            const SizedBox(height: 30),

            // --- 4. RESULTS DISPLAY ---
            if (_result != null) ...[
              const Divider(thickness: 2),
              const SizedBox(height: 10),

              Center(
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          height: 120,
                          width: 120,
                          child: CircularProgressIndicator(
                            value: _result!.overallScore / 100,
                            strokeWidth: 10,
                            backgroundColor: Colors.grey.shade200,
                            color: Colors.teal,
                          ),
                        ),
                        Text("${_result!.overallScore.toStringAsFixed(0)}%", style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.teal)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text("Overall Score", style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildMetricBox("Fluency", _result!.fluency),
                  _buildMetricBox("Pronunciation", _result!.pronunciation),
                  _buildMetricBox("Speed (WPM)", _result!.wpm),
                ],
              ),

              const SizedBox(height: 30),
              const Text("📝 Color-Coded Feedback:", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),

              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade300), boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 10)]),
                child: _buildRichTextTranscription(_result!.wordAnalysis),
              ),

              const SizedBox(height: 10),
              const Wrap(
                spacing: 15,
                children: [
                  Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.circle, color: Colors.green, size: 12), SizedBox(width: 5), Text("Perfect")]),
                  Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.circle, color: Colors.red, size: 12), SizedBox(width: 5), Text("Mistake")]),
                  Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.circle, color: Colors.grey, size: 12), SizedBox(width: 5), Text("Omitted")]),
                ],
              )
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildMetricBox(String label, double value) {
    return Column(
      children: [
        Text(value.toStringAsFixed(1), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}