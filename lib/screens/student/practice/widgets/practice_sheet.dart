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

  // --- TTS FUNCTION ---
  Future<void> _playTeacherVoice() async {
    if (_isRecording) return;
    setState(() => _isLoadingTTS = true);

    try {
      String? baseUrl = dotenv.env['API_URL'];
      if (baseUrl == null || baseUrl.isEmpty) {
        _showError("Error: API_URL not found in .env file");
        setState(() => _isLoadingTTS = false);
        return;
      }

      var uri = Uri.parse("$baseUrl/generate-teacher-voice/");
      var request = http.MultipartRequest('POST', uri);
      request.fields['text'] = widget.referenceText;

      var streamedResponse = await request.send();

      if (streamedResponse.statusCode == 200) {
        var response = await http.Response.fromStream(streamedResponse);
        final dir = await getTemporaryDirectory();
        final fileName = "teacher_${DateTime.now().millisecondsSinceEpoch}.mp3";
        final file = File('${dir.path}/$fileName');
        await file.writeAsBytes(response.bodyBytes, flush: true);

        if (mounted) {
          setState(() {
            _isLoadingTTS = false;
            _isSpeaking = true;
          });
        }
        await _audioPlayer.play(DeviceFileSource(file.path));
      } else {
        _showError("Server Error: ${streamedResponse.statusCode}");
        setState(() => _isLoadingTTS = false);
      }
    } catch (e) {
      _showError("Connection Failed. Check Server.");
      setState(() => _isLoadingTTS = false);
    }
  }

  // --- RECORDING FUNCTION ---
  Future<void> _toggleRecording() async {
    if (_isSpeaking) return;

    try {
      if (_isRecording) {
        final path = await _audioRecorder.stop();
        setState(() {
          _isRecording = false;
          _audioPath = path;
        });
      } else {
        if (await _audioRecorder.hasPermission()) {
          final Directory appDir = await getApplicationDocumentsDirectory();
          final String filePath = '${appDir.path}/rec_${DateTime.now().millisecondsSinceEpoch}.wav';

          const config = RecordConfig(
            encoder: AudioEncoder.wav,
            sampleRate: 44100,
            numChannels: 1,
          );

          await _audioRecorder.start(config, path: filePath);
          setState(() { _isRecording = true; _analysisResult = null; });
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

  // --- ANALYZE FUNCTION ---
  Future<void> _analyze() async {
    if (_audioPath == null) return;
    setState(() => _isAnalyzing = true);

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

  // --- SUBMIT FUNCTION (UPDATED) ---
  Future<void> _submitResults() async {
    if (_analysisResult == null) return;
    setState(() => _isAnalyzing = true);

    try {
      var scores = _analysisResult!['quality_scores'];
      var metrics = _analysisResult!['transcription_metrics'];
      var speaker = _analysisResult!['speaker_analysis'];
      String rawSpeech = _analysisResult!['full_transcription'] ?? "";

      double overall = double.tryParse(scores['overall_score'].toString()) ?? 0.0;
      double fluency = double.tryParse(scores['fluency'].toString()) ?? 0.0;
      double pronun = double.tryParse(scores['pronunciation'].toString()) ?? 0.0;
      double clarity = double.tryParse(scores['clarity'].toString()) ?? 0.0;
      double accuracy = double.tryParse(metrics['accuracy_from_wer'].toString().replaceAll('%', '')) ?? 0.0;
      double wpm = double.tryParse(metrics['words_per_minute'].toString()) ?? 0.0;
      String ageGroup = speaker['predicted_age_group'] ?? "Unknown";

      // ⏱️ DURATION (From Server Response)
      double durationVal = double.tryParse(_analysisResult?['audio_duration']?.toString() ?? "30") ?? 30.0;
      int durationInSeconds = durationVal.round();

      List<dynamic> words = _analysisResult!['word_analysis'] ?? [];
      List<String> redWords = words
          .where((w) => w['color'] == 'red')
          .map((w) => w['text'].toString().toLowerCase())
          .toList();

      // 🏆 GAMIFICATION CALL (Updated)
      await _gamificationService.processSubmission(
        userId: widget.studentId, // 👈 PASS USER ID
        baseCoins: widget.basePoints,
        accuracyScore: overall.round(),
        durationSeconds: durationInSeconds, // 👈 PASS DURATION
      );

      // 💾 FIRESTORE BATCH SAVE
      final batch = FirebaseFirestore.instance.batch();

      DocumentReference subRef = FirebaseFirestore.instance.collection('submissions').doc();
      batch.set(subRef, {
        'assignment_id': widget.assignmentId,
        'student_id': widget.studentId,
        'submitted_at': FieldValue.serverTimestamp(),
        'full_transcription': rawSpeech,
        'accuracy_score': overall.round(),
        'fluency_score': fluency,
        'pronunciation_score': pronun,
        'clarity_score': clarity,
        'transcription_accuracy': accuracy,
        'wpm': wpm,
        'detected_age': ageGroup,
        'word_analysis': words,
        'status': 'completed',
      });

      if (redWords.isNotEmpty) {
        DocumentReference studentRef = FirebaseFirestore.instance.collection('users').doc(widget.studentId);
        batch.update(studentRef, {
          'mistake_words': FieldValue.arrayUnion(redWords),
        });
      }

      await batch.commit();

      if(mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Submission Saved! 🎉"), backgroundColor: Colors.green)
        );
      }
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error saving: $e")));
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

  @override
  Widget build(BuildContext context) {
    // ... (YOUR EXISTING UI CODE IS PERFECT, NO CHANGES NEEDED HERE) ...
    // Just keeping the structure short for copy-paste
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
                // VIEW A: RESULT
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
                      userTranscription: _analysisResult!['full_transcription'] ?? "",
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
                // VIEW B: RECORDING UI (Kept same as yours)
                    : Column(
                  children: [
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: double.infinity,
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color: _isSpeaking ? Colors.orange.shade300 : Colors.grey.shade200,
                              width: _isSpeaking ? 3 : 1,
                            ),
                            boxShadow: [
                              BoxShadow(color: _isSpeaking ? Colors.orange.withOpacity(0.2) : Colors.grey.shade200, blurRadius: 10)
                            ]
                        ),
                        child: Column(
                          children: [
                            // ... (YOUR EXISTING WIDGET CODE FOR TEXT & BADGE) ...
                            Expanded(child: Center(child: SingleChildScrollView(child: Text(widget.referenceText, textAlign: TextAlign.center, style: TextStyle(fontSize: 26, color: _isSpeaking ? Colors.deepOrange.shade900 : Colors.black87))))),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    // CONTROLS
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildNeumorphicButton(icon: Icons.volume_up_rounded, label: "Listen", color: Colors.blueAccent, isActive: !_isRecording, onTap: _playTeacherVoice),
                          GestureDetector(
                            onTap: _isSpeaking ? null : _toggleRecording,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              height: 80, width: 80,
                              decoration: BoxDecoration(
                                  color: _isSpeaking ? Colors.grey.shade300 : (_isRecording ? Colors.red : Colors.white),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.red.shade100, width: 4)
                              ),
                              child: Icon(_isRecording ? Icons.stop_rounded : Icons.mic_rounded, color: _isSpeaking ? Colors.grey : (_isRecording ? Colors.white : Colors.red), size: 40),
                            ),
                          ),
                          _buildNeumorphicButton(icon: Icons.upload_file_rounded, label: "Upload", color: Colors.purpleAccent, isActive: !_isRecording && !_isSpeaking, onTap: _pickFile),
                        ],
                      ),
                    ),
                    if (_audioPath != null)
                      SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _isAnalyzing ? null : _analyze, style: ElevatedButton.styleFrom(backgroundColor: Colors.black87, padding: const EdgeInsets.symmetric(vertical: 18)), child: _isAnalyzing ? const CircularProgressIndicator(color: Colors.white) : const Text("ANALYZE RECORDING", style: TextStyle(color: Colors.white))))
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNeumorphicButton({required IconData icon, required String label, required Color color, required bool isActive, required VoidCallback onTap}) {
    return Column(children: [
      GestureDetector(onTap: isActive ? onTap : null, child: Opacity(opacity: isActive ? 1.0 : 0.4, child: Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 10, offset: const Offset(0, 5))]), child: Icon(icon, color: color, size: 28)))),
      const SizedBox(height: 8),
      Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 12))
    ]);
  }
}