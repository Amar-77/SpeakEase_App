import 'dart:io';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  final AudioRecorder _audioRecorder = AudioRecorder();
  final ApiService _apiService = ApiService();
  final GamificationService _gamificationService = GamificationService();

  String? _audioPath;
  bool _isRecording = false;
  bool _isAnalyzing = false;
  Map<String, dynamic>? _analysisResult;

  @override
  void dispose() {
    _audioRecorder.dispose();
    super.dispose();
  }

  // --- 1. RECORDING ---
  Future<void> _toggleRecording() async {
    try {
      if (_isRecording) {
        final path = await _audioRecorder.stop();
        setState(() { _isRecording = false; _audioPath = path; });
      } else {
        if (await _audioRecorder.hasPermission()) {
          final Directory appDir = await getApplicationDocumentsDirectory();
          final String filePath = '${appDir.path}/rec_${DateTime.now().millisecondsSinceEpoch}.m4a';
          await _audioRecorder.start(const RecordConfig(), path: filePath);
          setState(() { _isRecording = true; _analysisResult = null; });
        }
      }
    } catch (e) {
      print("Record Error: $e");
    }
  }

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.audio);
    if (result != null) {
      setState(() { _audioPath = result.files.single.path; _analysisResult = null; });
    }
  }

  // --- 2. ANALYZE ---
  Future<void> _analyze() async {
    if (_audioPath == null) return;
    setState(() => _isAnalyzing = true);

    var response = await _apiService.analyzeAudio(_audioPath!, widget.referenceText);

    if (response != null) {
      setState(() { _analysisResult = response; });
    } else {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Analysis Failed. Check Server.")));
    }
    setState(() => _isAnalyzing = false);
  }

  // --- 3. RETRY ---
  void _retry() {
    setState(() {
      _audioPath = null;
      _analysisResult = null;
      _isRecording = false;
    });
  }

  // --- 4. SUBMIT (ALL METRICS) ---
  Future<void> _submitResults() async {
    if (_analysisResult == null) return;
    setState(() => _isAnalyzing = true);

    try {
      print("Saving Full Analysis Results...");

      // A. Extract All Metrics safely
      var scores = _analysisResult!['quality_scores'];
      var metrics = _analysisResult!['transcription_metrics'];
      var speaker = _analysisResult!['speaker_analysis'];

      double overall = double.tryParse(scores['overall_score'].toString()) ?? 0.0;
      double fluency = double.tryParse(scores['fluency'].toString()) ?? 0.0;
      double pronun = double.tryParse(scores['pronunciation'].toString()) ?? 0.0;
      double clarity = double.tryParse(scores['clarity'].toString()) ?? 0.0;

      // Clean up percentage strings if needed (e.g. "95.5%")
      double accuracy = double.tryParse(metrics['accuracy_from_wer'].toString().replaceAll('%', '')) ?? 0.0;
      double wpm = double.tryParse(metrics['words_per_minute'].toString()) ?? 0.0;
      String ageGroup = speaker['predicted_age_group'] ?? "Unknown";

      List<dynamic> words = _analysisResult!['word_analysis'] ?? [];

      // B. Gamification
      Map<String, dynamic> rewards = await _gamificationService.processSubmission(
        baseCoins: widget.basePoints,
        accuracyScore: overall.round(),
      );

      // C. Save EVERYTHING to Firestore
      await FirebaseFirestore.instance.collection('submissions').add({
        'assignment_id': widget.assignmentId,
        'student_id': widget.studentId,
        'submitted_at': FieldValue.serverTimestamp(),

        // Core Scores
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

      print("Firestore Saved Successfully!");

      if(mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Saved! +${rewards['coins']} Coins earned! 🎉"), backgroundColor: Colors.green)
        );
      }
    } catch (e) {
      print("SAVE ERROR: $e");
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error saving: $e")));
    } finally {
      if(mounted) setState(() => _isAnalyzing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text("Practice Mode", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))
            ]),
            const Divider(),

            Expanded(
              child: _analysisResult != null
                  ? SingleChildScrollView(
                child: Column(
                  children: [
                    // 1. RESULT VIEW (Passes ALL data now)
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

                    // 2. ACTION BUTTONS
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isAnalyzing ? null : _retry,
                            icon: const Icon(Icons.refresh),
                            label: const Text("RETRY"),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.orange,
                              side: const BorderSide(color: Colors.orange),
                              minimumSize: const Size(0, 50),
                            ),
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isAnalyzing ? null : _submitResults,
                            icon: const Icon(Icons.check),
                            label: _isAnalyzing
                                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Text("SUBMIT"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(0, 50),
                            ),
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              )
                  : Column(
                children: [
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(10)),
                      child: SingleChildScrollView(child: Text(widget.referenceText, style: const TextStyle(fontSize: 18, height: 1.5))),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    GestureDetector(onTap: _toggleRecording, child: CircleAvatar(radius: 35, backgroundColor: _isRecording ? Colors.red : Colors.blue, child: Icon(_isRecording ? Icons.stop : Icons.mic, color: Colors.white, size: 30))),
                    const SizedBox(width: 20),
                    IconButton(icon: const Icon(Icons.upload_file, size: 30, color: Colors.purple), onPressed: _pickFile),
                  ]),
                  if (_audioPath != null) ...[
                    const SizedBox(height: 20),
                    ElevatedButton(onPressed: _isAnalyzing ? null : _analyze, style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, minimumSize: const Size(200, 50)), child: _isAnalyzing ? const CircularProgressIndicator(color: Colors.white) : const Text("ANALYZE NOW"))
                  ]
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}