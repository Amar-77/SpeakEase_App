import 'dart:io';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:speakease/services/api_service.dart';
import 'package:speakease/services/gamification_service.dart';
import 'detailed_result_view.dart';

class PracticeRecordingSheet extends StatefulWidget {
  final String assignmentId;
  final String referenceText;
  final int basePoints;
  final String studentId;

  const PracticeRecordingSheet({
    super.key,
    required this.assignmentId,
    required this.referenceText,
    required this.basePoints,
    required this.studentId
  });

  @override
  State<PracticeRecordingSheet> createState() => _PracticeRecordingSheetState();
}

class _PracticeRecordingSheetState extends State<PracticeRecordingSheet> {
  // SERVICES
  final AudioRecorder _audioRecorder = AudioRecorder();
  final ApiService _apiService = ApiService();
  final GamificationService _gamificationService = GamificationService();
  final AudioPlayer _audioPlayer = AudioPlayer();

  // RECORDING & ANALYSIS STATES
  String? _audioPath;
  bool _isRecording = false;
  bool _isAnalyzing = false;
  Map<String, dynamic>? _analysisResult;

  // TTS (TEACHER VOICE) STATES
  bool _isSpeaking = false;
  bool _isLoadingTTS = false;

  @override
  void initState() {
    super.initState();
    // Listener: Turn off glowing effect when audio finishes
    _audioPlayer.onPlayerComplete.listen((event) {
      if (mounted) setState(() => _isSpeaking = false);
    });
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  // ===========================================================================
  // 🔊 FUNCTION 1: TEACHER TTS (TEXT-TO-SPEECH)
  // ===========================================================================
  Future<void> _playTeacherVoice() async {
    if (_isRecording) return; // Lock if recording

    setState(() => _isLoadingTTS = true);

    try {
      // 1. Get URL from .env (Security Best Practice)
      String? baseUrl = dotenv.env['API_URL'];

      if (baseUrl == null || baseUrl.isEmpty) {
        _showError("Error: API_URL not found in .env file");
        setState(() => _isLoadingTTS = false);
        return;
      }

      print("🎙️ Fetching TTS from: $baseUrl/generate-teacher-voice/");

      var uri = Uri.parse("$baseUrl/generate-teacher-voice/");
      var request = http.MultipartRequest('POST', uri);
      request.fields['text'] = widget.referenceText;

      var streamedResponse = await request.send();

      if (streamedResponse.statusCode == 200) {
        var response = await http.Response.fromStream(streamedResponse);

        // 2. Save Audio to Temp Directory
        final dir = await getTemporaryDirectory();
        final fileName = "teacher_${DateTime.now().millisecondsSinceEpoch}.mp3";
        final file = File('${dir.path}/$fileName');

        await file.writeAsBytes(response.bodyBytes, flush: true);

        // 3. Update UI & Play
        if (mounted) {
          setState(() {
            _isLoadingTTS = false;
            _isSpeaking = true; // Triggers UI Glow
          });
        }

        await _audioPlayer.play(DeviceFileSource(file.path));

      } else {
        print("❌ Server Error: ${streamedResponse.statusCode}");
        _showError("Server Error: ${streamedResponse.statusCode}");
        setState(() => _isLoadingTTS = false);
      }
    } catch (e) {
      print("❌ Connection Error: $e");
      _showError("Connection Failed. Check Server.");
      setState(() => _isLoadingTTS = false);
    }
  }

  // ===========================================================================
  // 🎤 FUNCTION 2: RECORDING & FILES
  // ===========================================================================
  Future<void> _toggleRecording() async {
    if (_isSpeaking) return; // Lock if Teacher is speaking

    try {
      if (_isRecording) {
        // STOP RECORDING
        final path = await _audioRecorder.stop();
        setState(() {
          _isRecording = false;
          _audioPath = path;
        });
      } else {
        // START RECORDING
        if (await _audioRecorder.hasPermission()) {
          final dir = await getApplicationDocumentsDirectory();
          final path = '${dir.path}/rec_${DateTime.now().millisecondsSinceEpoch}.m4a';

          await _audioRecorder.start(const RecordConfig(), path: path);

          setState(() {
            _isRecording = true;
            _analysisResult = null; // Reset previous results
          });
        }
      }
    } catch (e) {
      print("Record Error: $e");
      _showError("Microphone Error");
    }
  }

  Future<void> _pickFile() async {
    if (_isSpeaking) return;
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.audio);
    if (result != null) {
      setState(() {
        _audioPath = result.files.single.path;
        _analysisResult = null;
      });
    }
  }

  // ===========================================================================
  // 🧠 FUNCTION 3: ANALYSIS & SUBMISSION
  // ===========================================================================
  Future<void> _analyze() async {
    if (_audioPath == null) return;
    setState(() => _isAnalyzing = true);

    // Call Analysis API
    var response = await _apiService.analyzeAudio(_audioPath!, widget.referenceText);

    setState(() {
      _analysisResult = response;
      _isAnalyzing = false;
    });

    if (response == null && mounted) _showError("Analysis Failed. Try again.");
  }

  void _retry() {
    setState(() {
      _audioPath = null;
      _analysisResult = null;
      _isRecording = false;
      _isSpeaking = false;
    });
  }

  Future<void> _submitResults() async {
    if (_analysisResult == null) return;
    setState(() => _isAnalyzing = true);

    try {
      var scores = _analysisResult!['quality_scores'];
      var metrics = _analysisResult!['transcription_metrics'];
      var speaker = _analysisResult!['speaker_analysis'];

      // Helper to parse messy strings (e.g., "95.5%")
      double safeParse(dynamic val) => double.tryParse(val.toString().replaceAll('%','')) ?? 0.0;

      // Save to Firebase
      await FirebaseFirestore.instance.collection('submissions').add({
        'assignment_id': widget.assignmentId,
        'student_id': widget.studentId,
        'submitted_at': FieldValue.serverTimestamp(),
        'accuracy_score': safeParse(scores['overall_score']).round(),
        'fluency_score': safeParse(scores['fluency']),
        'pronunciation_score': safeParse(scores['pronunciation']),
        'clarity_score': safeParse(scores['clarity']),
        'transcription_accuracy': safeParse(metrics['accuracy_from_wer']),
        'wpm': safeParse(metrics['words_per_minute']),
        'detected_age': speaker['predicted_age_group'] ?? "Unknown",
        'word_analysis': _analysisResult!['word_analysis'] ?? [],
        'status': 'completed',
      });

      // Award Points
      await _gamificationService.processSubmission(
          baseCoins: widget.basePoints,
          accuracyScore: safeParse(scores['overall_score']).round()
      );

      if(mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Submission Saved! 🎉"), backgroundColor: Colors.green)
        );
      }
    } catch (e) {
      _showError("Save Error: $e");
    } finally {
      if(mounted) setState(() => _isAnalyzing = false);
    }
  }

  void _showError(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red)
      );
    }
  }

  // ===========================================================================
  // 🎨 UI BUILDER
  // ===========================================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text("Practice Mode", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.black),
            onPressed: () => Navigator.pop(context)
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10.0),
          child: Column(
            children: [
              Expanded(
                child: _analysisResult != null
                // ---------------------------------------------------------
                // VIEW A: ANALYSIS RESULTS (Existing)
                // ---------------------------------------------------------
                    ? SingleChildScrollView(
                  child: Column(children: [
                    DetailedResultView(
                      overallScore: double.tryParse(_analysisResult!['quality_scores']['overall_score'].toString()) ?? 0,
                      fluency: double.tryParse(_analysisResult!['quality_scores']['fluency'].toString()) ?? 0,
                      pronunciation: double.tryParse(_analysisResult!['quality_scores']['pronunciation'].toString()) ?? 0,
                      clarity: double.tryParse(_analysisResult!['quality_scores']['clarity'].toString()) ?? 0,
                      accuracy: double.tryParse(_analysisResult!['transcription_metrics']['accuracy_from_wer'].toString().replaceAll('%','')) ?? 0,
                      wpm: double.tryParse(_analysisResult!['transcription_metrics']['words_per_minute'].toString()) ?? 0,
                      ageGroup: _analysisResult!['speaker_analysis']['predicted_age_group'] ?? "?",
                      wordAnalysis: _analysisResult!['word_analysis'] ?? [],
                    ),
                    const SizedBox(height: 20),
                    Row(children: [
                      Expanded(child: OutlinedButton(
                          onPressed: _retry,
                          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15)),
                          child: const Text("TRY AGAIN")
                      )),
                      const SizedBox(width: 15),
                      Expanded(child: ElevatedButton(
                          onPressed: _submitResults,
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, padding: const EdgeInsets.symmetric(vertical: 15)),
                          child: const Text("SUBMIT RESULT", style: TextStyle(color: Colors.white))
                      )),
                    ])
                  ]),
                )

                // ---------------------------------------------------------
                // VIEW B: TELEPROMPTER & RECORDING CONTROLS
                // ---------------------------------------------------------
                    : Column(
                  children: [
                    // --- 1. TELEPROMPTER CARD ---
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        width: double.infinity,
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color: _isSpeaking ? Colors.orange.shade300 : Colors.grey.shade200,
                              width: _isSpeaking ? 3 : 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: _isSpeaking ? Colors.orange.withOpacity(0.2) : Colors.grey.shade200,
                                blurRadius: _isSpeaking ? 20 : 10,
                                offset: const Offset(0, 5),
                              )
                            ]
                        ),
                        child: Column(
                          children: [
                            // A. TOP HEADER (Badge Area - No Blocking!)
                            Container(
                              height: 60,
                              alignment: Alignment.center,
                              child: _isSpeaking
                                  ? Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                    color: Colors.orange.shade50,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.orange.shade200)
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.volume_up_rounded, color: Colors.deepOrange.shade700, size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                        "TEACHER READING...",
                                        style: TextStyle(color: Colors.deepOrange.shade800, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.0)
                                    )
                                  ],
                                ),
                              )
                                  : (_isRecording
                                  ? Text("🔴 LISTENING...", style: TextStyle(color: Colors.red.shade400, fontWeight: FontWeight.bold, letterSpacing: 1.2))
                                  : null),
                            ),

                            // B. SCROLLABLE TEXT AREA
                            Expanded(
                              child: Stack(
                                children: [
                                  Center(
                                    child: SingleChildScrollView(
                                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
                                      child: Text(
                                        widget.referenceText,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 26,
                                          height: 1.6,
                                          color: _isSpeaking ? Colors.deepOrange.shade900 : Colors.black87,
                                          fontWeight: _isSpeaking ? FontWeight.w600 : FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Loading Overlay (Spinner)
                                  if (_isLoadingTTS)
                                    Container(
                                      color: Colors.white.withOpacity(0.8),
                                      child: Center(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
                                          decoration: BoxDecoration(
                                            color: Colors.black87,
                                            borderRadius: BorderRadius.circular(30),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                                              SizedBox(width: 15),
                                              Text("Loading Voice...", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600))
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),

                    // --- 2. CONTROLS ROW ---
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // LISTEN BUTTON
                          _buildNeumorphicButton(
                            icon: Icons.volume_up_rounded,
                            label: "Listen",
                            color: Colors.blueAccent,
                            isActive: !_isRecording,
                            onTap: _playTeacherVoice,
                          ),

                          // RECORD BUTTON (Main)
                          GestureDetector(
                            onTap: _isSpeaking ? null : _toggleRecording,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              height: 80, width: 80,
                              decoration: BoxDecoration(
                                  color: _isSpeaking ? Colors.grey.shade300 : (_isRecording ? Colors.red : Colors.white),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: _isSpeaking ? Colors.grey.shade300 : (_isRecording ? Colors.red : Colors.red.shade100),
                                      width: 4
                                  ),
                                  boxShadow: [
                                    if (!_isSpeaking)
                                      BoxShadow(
                                          color: _isRecording ? Colors.red.withOpacity(0.4) : Colors.red.withOpacity(0.1),
                                          blurRadius: 20,
                                          offset: const Offset(0, 10)
                                      )
                                  ]
                              ),
                              child: Icon(
                                _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                                color: _isSpeaking ? Colors.grey : (_isRecording ? Colors.white : Colors.red),
                                size: 40,
                              ),
                            ),
                          ),

                          // UPLOAD BUTTON
                          _buildNeumorphicButton(
                            icon: Icons.upload_file_rounded,
                            label: "Upload",
                            color: Colors.purpleAccent,
                            isActive: !_isRecording && !_isSpeaking,
                            onTap: _pickFile,
                          ),
                        ],
                      ),
                    ),

                    // ANALYZE BUTTON
                    if (_audioPath != null) ...[
                      SizedBox(width: double.infinity, child: ElevatedButton(
                        onPressed: _isAnalyzing ? null : _analyze,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black87,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                        ),
                        child: _isAnalyzing
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text("ANALYZE RECORDING", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
                      ))
                    ]
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper Widget for Side Buttons
  Widget _buildNeumorphicButton({
    required IconData icon,
    required String label,
    required Color color,
    required bool isActive,
    required VoidCallback onTap
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: isActive ? onTap : null,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: isActive ? 1.0 : 0.4,
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: Colors.grey.shade200,
                        blurRadius: 10,
                        offset: const Offset(0, 5)
                    )
                  ]
              ),
              child: Icon(icon, color: color, size: 28),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.w500))
      ],
    );
  }
}