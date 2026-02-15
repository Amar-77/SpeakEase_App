import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// Import the Report Card Screen (Make sure this file exists!)
import 'report_card_screen.dart';

class SpeakyChatScreen extends StatefulWidget {
  const SpeakyChatScreen({Key? key}) : super(key: key);

  @override
  State<SpeakyChatScreen> createState() => _SpeakyChatScreenState();
}

class _SpeakyChatScreenState extends State<SpeakyChatScreen> {
  // --- CONFIGURATION ---
  // ⚠️ REPLACE WITH YOUR ACTUAL SERVER IP
  String? baseUrl = dotenv.env['API_URL'];

  // --- STATE ---
  late String sessionId;
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();

  List<Map<String, String>> chatHistory = [];
  bool isRecording = false;
  bool isProcessing = false;

  // COUNTER LOGIC
  int turnCount = 0;
  final int maxTurns = 5;

  @override
  void initState() {
    super.initState();
    sessionId = const Uuid().v4();
    chatHistory.add({
      "role": "ai",
      "content": "Hi! I'm Speaky. What do you want to talk about today?"
    });
  }

  @override
  void dispose() {
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }

  // --- 1. RECORDING ---
  Future<void> startRecording() async {
    var status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Microphone permission required!")));
      return;
    }

    final dir = await getTemporaryDirectory();
    String path = '${dir.path}/temp_voice.wav';

    await _recorder.start(const RecordConfig(), path: path);
    setState(() => isRecording = true);
  }

  Future<void> stopRecording() async {
    final path = await _recorder.stop();
    setState(() => isRecording = false);

    if (path != null) {
      await sendAudioTurn(path);
    }
  }

  // --- 2. SEND TO SERVER & HANDLE TURN LIMIT ---
  Future<void> sendAudioTurn(String audioPath) async {
    setState(() => isProcessing = true);

    try {
      var uri = Uri.parse('$baseUrl/chat-batch/');
      var request = http.MultipartRequest('POST', uri);

      request.files.add(await http.MultipartFile.fromPath('file', audioPath));
      request.fields['session_id'] = sessionId;
      request.fields['chat_history'] = jsonEncode(chatHistory);

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        // A. Update Chat UI
        String userText = response.headers['x-user-text'] ?? "...";
        String aiText = response.headers['x-ai-text'] ?? "...";

        setState(() {
          chatHistory.add({"role": "user", "content": userText});
          chatHistory.add({"role": "ai", "content": aiText});
          turnCount++; // INCREMENT COUNTER
          isProcessing = false;
        });

        // B. Play Audio Response
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/response.mp3');
        await file.writeAsBytes(response.bodyBytes);
        await _player.play(DeviceFileSource(file.path));

        // C. CHECK LIMIT (If 5 turns reached -> End Session)
        if (turnCount >= maxTurns) {
          // Wait for audio to finish (approximate) or just trigger
          await Future.delayed(const Duration(seconds: 4));
          if (mounted) {
            _finishSessionAndShowReport();
          }
        }

      } else {
        print("Server Error: ${response.statusCode}");
        setState(() => isProcessing = false);
      }
    } catch (e) {
      print("Network Error: $e");
      setState(() => isProcessing = false);
    }
  }

  // --- 3. END SESSION & NAVIGATE TO REPORT ---
  Future<void> _finishSessionAndShowReport() async {
    // Show a loading dialog so user knows report is generating
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final uri = Uri.parse('$baseUrl/end-session-score/$sessionId');
      final response = await http.get(uri);

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Navigate to Report Screen
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => ReportCardScreen(data: data),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Failed to generate report.")));
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // Close dialog on error
      print("Report Error: $e");
    }
  }

  // --- UI BUILD ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Speaky ($turnCount/$maxTurns)"), // Show progress in title
        backgroundColor: Colors.white,
        elevation: 0,
        titleTextStyle: const TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: const Icon(Icons.flag_outlined, color: Colors.red),
            onPressed: () => _finishSessionAndShowReport(), // Manual End
            tooltip: "End Session Early",
          ),
        ],
      ),
      body: Column(
        children: [
          // Chat Area
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: chatHistory.length,
              itemBuilder: (context, index) {
                final msg = chatHistory[index];
                final isUser = msg['role'] == 'user';
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                    decoration: BoxDecoration(
                      color: isUser ? Colors.blue[600] : Colors.grey[200],
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(20),
                        topRight: const Radius.circular(20),
                        bottomLeft: isUser ? const Radius.circular(20) : Radius.zero,
                        bottomRight: isUser ? Radius.zero : const Radius.circular(20),
                      ),
                    ),
                    child: Text(
                      msg['content']!,
                      style: TextStyle(
                        color: isUser ? Colors.white : Colors.black87,
                        fontSize: 16,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Loading Indicator
          if (isProcessing)
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 10),
                  Text("Speaky is thinking...", style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),

          // Bottom Recording Area
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -5))],
            ),
            child: Column(
              children: [
                GestureDetector(
                  // Long Press to Record
                  onLongPressStart: (_) => startRecording(),
                  onLongPressEnd: (_) => stopRecording(),
                  // Tap to Toggle (Optional)
                  onTap: () {
                    if (!isRecording) startRecording(); else stopRecording();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 80,
                    width: 80,
                    decoration: BoxDecoration(
                        color: isRecording ? Colors.redAccent : Colors.blueAccent,
                        shape: BoxShape.circle,
                        boxShadow: [
                          if (isRecording)
                            BoxShadow(color: Colors.redAccent.withOpacity(0.5), blurRadius: 20, spreadRadius: 5)
                        ]
                    ),
                    child: Icon(
                      isRecording ? Icons.mic_off : Icons.mic,
                      color: Colors.white,
                      size: 35,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  isRecording ? "Listening..." : "Hold to Speak",
                  style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w600),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}