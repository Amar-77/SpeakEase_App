import 'dart:io';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:speakease/services/api_service.dart';
import 'package:speakease/services/gamification_service.dart';
import 'package:speakease/services/eleven_labs_service.dart'; // 1. IMPORT SERVICE
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
  final ElevenLabsService _ttsService = ElevenLabsService(); // 2. INITIALIZE SERVICE

  String? _audioPath;
  bool _isRecording = false;
  bool _isAnalyzing = false;
  bool _isTtsLoading = false; // Track TTS state
  Map<String, dynamic>? _analysisResult;

  @override
  void dispose() {
    _audioRecorder.dispose();
    super.dispose();
  }

  // --- TTS LOGIC (ELEVEN LABS) ---
  Future<void> _playAIVoice() async {
    setState(() => _isTtsLoading = true);
    await _ttsService.speak(widget.referenceText); //
    if (mounted) setState(() => _isTtsLoading = false);
  }

  // --- RECORDING LOGIC ---
  Future<void> _toggleRecording() async {
    try {
      if (_isRecording) {
        final path = await _audioRecorder.stop(); //
        setState(() { _isRecording = false; _audioPath = path; });
      } else {
        if (await _audioRecorder.hasPermission()) {
          final Directory appDir = await getApplicationDocumentsDirectory();
          final String filePath = '${appDir.path}/rec_${DateTime.now().millisecondsSinceEpoch}.m4a';
          await _audioRecorder.start(const RecordConfig(), path: filePath); //
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

  // --- ANALYZE LOGIC ---
  Future<void> _analyze() async {
    if (_audioPath == null) return;
    setState(() => _isAnalyzing = true);

    var response = await _apiService.analyzeAudio(_audioPath!, widget.referenceText);

    if (response != null) {
      setState(() { _analysisResult = response; });
    } else {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Analysis Failed.")));
    }
    setState(() => _isAnalyzing = false);
  }

  void _retry() {
    setState(() {
      _audioPath = null;
      _analysisResult = null;
      _isRecording = false;
    });
  }

  Future<void> _submitResults() async {
    if (_analysisResult == null) return;
    setState(() => _isAnalyzing = true);

    try {
      var scores = _analysisResult!['quality_scores'];
      var metrics = _analysisResult!['transcription_metrics'];
      var speaker = _analysisResult!['speaker_analysis'];

      double overall = double.tryParse(scores['overall_score'].toString()) ?? 0.0;
      double accuracy = double.tryParse(metrics['accuracy_from_wer'].toString().replaceAll('%', '')) ?? 0.0;
      
      Map<String, dynamic> rewards = await _gamificationService.processSubmission(
        baseCoins: widget.basePoints,
        accuracyScore: overall.round(),
      );

      await FirebaseFirestore.instance.collection('submissions').add({
        'assignment_id': widget.assignmentId,
        'student_id': widget.studentId,
        'submitted_at': FieldValue.serverTimestamp(),
        'accuracy_score': overall.round(),
        'fluency_score': double.tryParse(scores['fluency'].toString()) ?? 0.0,
        'pronunciation_score': double.tryParse(scores['pronunciation'].toString()) ?? 0.0,
        'clarity_score': double.tryParse(scores['clarity'].toString()) ?? 0.0,
        'transcription_accuracy': accuracy,
        'wpm': double.tryParse(metrics['words_per_minute'].toString()) ?? 0.0,
        'detected_age': speaker['predicted_age_group'] ?? "Unknown",
        'word_analysis': _analysisResult!['word_analysis'] ?? [],
        'status': 'completed',
      });

      if(mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Saved! +${rewards['coins']} Coins earned! 🎉"), backgroundColor: Colors.green)
        );
      }
    } catch (e) {
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
                  ? _buildResultView() 
                  : _buildPracticeView(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPracticeView() {
    return Column(
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
        
        // --- BUTTON ROW ---
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          
          // 3. SPEAKER BUTTON (LEFT OF MIC)
          GestureDetector(
            onTap: _isTtsLoading ? null : _playAIVoice,
            child: CircleAvatar(
              radius: 25,
              backgroundColor: Colors.blue.shade100,
              child: _isTtsLoading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(Icons.volume_up, color: Colors.blue.shade700),
            ),
          ),
          
          const SizedBox(width: 25),

          // RECORD BUTTON (CENTER)
          GestureDetector(
            onTap: _toggleRecording, 
            child: CircleAvatar(
              radius: 35, 
              backgroundColor: _isRecording ? Colors.red : Colors.blue, 
              child: Icon(_isRecording ? Icons.stop : Icons.mic, color: Colors.white, size: 30)
            )
          ),
          
          const SizedBox(width: 25),

          // UPLOAD BUTTON (RIGHT)
          IconButton(icon: const Icon(Icons.upload_file, size: 30, color: Colors.purple), onPressed: _pickFile),
        ]),
        
        if (_audioPath != null) ...[
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _isAnalyzing ? null : _analyze, 
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, minimumSize: const Size(200, 50)), 
            child: _isAnalyzing ? const CircularProgressIndicator(color: Colors.white) : const Text("ANALYZE NOW")
          )
        ]
      ],
    );
  }

  Widget _buildResultView() {
    return SingleChildScrollView(
      child: Column(
        children: [
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
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isAnalyzing ? null : _retry,
                  icon: const Icon(Icons.refresh),
                  label: const Text("RETRY"),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.orange, side: const BorderSide(color: Colors.orange), minimumSize: const Size(0, 50)),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isAnalyzing ? null : _submitResults,
                  icon: const Icon(Icons.check),
                  label: _isAnalyzing ? const CircularProgressIndicator(color: Colors.white) : const Text("SUBMIT"),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white, minimumSize: const Size(0, 50)),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}