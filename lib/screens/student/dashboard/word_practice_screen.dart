import 'dart:io';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:speakease/screens/student/practice/widgets/detailed_result_view.dart';
import 'package:speakease/services/api_service.dart';
import 'package:speakease/services/practice_api_service.dart';

class WordPracticeScreen extends StatefulWidget {
  final List<String> mistakeWords;
  final String studentId;

  const WordPracticeScreen({
    super.key,
    required this.mistakeWords,
    required this.studentId,
  });

  @override
  State<WordPracticeScreen> createState() => _WordPracticeScreenState();
}

class _WordPracticeScreenState extends State<WordPracticeScreen> {
  final AudioRecorder _audioRecorder = AudioRecorder();
  final PracticeApiService _practiceApi = PracticeApiService();
  final ApiService _analysisApi = ApiService();

  String? _selectedWord;
  String? _practiceText;
  String? _audioPath;
  bool _isLoading = false;
  bool _isRecording = false;
  bool _isAnalyzing = false;
  Map<String, dynamic>? _analysisResult;
  List<String> _currentMistakeWords = [];

  @override
  void initState() {
    super.initState();
    _currentMistakeWords = List.from(widget.mistakeWords);
  }

  // --- API / LOGIC FUNCTIONS ---

  Future<void> _generateForWord(String word) async {
    setState(() {
      _selectedWord = word;
      _practiceText = null;
      _analysisResult = null;
      _audioPath = null;
      _isRecording = false;
      _isLoading = true;
    });

    final text = await _practiceApi.generatePractice(sentence: "", weakArea: word);

    if (mounted) {
      setState(() {
        _practiceText = text.isNotEmpty ? text : "Let's practice the word $word.";
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleRecording() async {
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
            sampleRate: 16000,
            numChannels: 1,
          );

          await _audioRecorder.start(config, path: filePath);
          setState(() {
            _isRecording = true;
            _analysisResult = null;
          });
        }
      }
    } catch (e) {
      debugPrint("Record Error: $e");
    }
  }

  Future<void> _analyzeReview() async {
    if (_audioPath == null || _practiceText == null) return;
    setState(() => _isAnalyzing = true);
    final response = await _analysisApi.analyzeAudio(_audioPath!, _practiceText!);
    if (mounted) {
      setState(() {
        _analysisResult = response;
        _isAnalyzing = false;
      });
    }
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    super.dispose();
  }

  // --- UI BUILDERS ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Clean white background matching Figma
      appBar: AppBar(
        title: const Text("Mastery Hub", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
        elevation: 0,
        backgroundColor: Colors.white,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _currentMistakeWords.isEmpty
          ? const Center(
          child: Text("You've mastered all your words! 🎉", style: TextStyle(fontSize: 16, color: Colors.grey)))
          : ListView.builder(
        padding: const EdgeInsets.all(20),
        physics: const BouncingScrollPhysics(),
        itemCount: _currentMistakeWords.length,
        itemBuilder: (context, index) {
          final word = _currentMistakeWords[index];
          final isExpanded = _selectedWord == word;

          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: isExpanded ? _buildExpandedCard(word) : _buildCollapsedCard(word),
            ),
          );
        },
      ),
    );
  }

  // 1. COLLAPSED STATE (Grey Card)
  Widget _buildCollapsedCard(String word) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
      decoration: BoxDecoration(
        color: const Color(0xFFDCDCDC), // Light Grey from Figma
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              _capitalize(word),
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: Color(0xFF2D2D2D), // Very dark grey
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 16),
          GestureDetector(
            onTap: () => _generateForWord(word),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFF9B54), // Orange from Figma
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF9B54).withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome, color: Colors.black87, size: 16), // ✨ icon
                  SizedBox(width: 6),
                  Text(
                    "Generate\nstory",
                    style: TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      height: 1.2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 2. EXPANDED STATE (Tan/Peach Card)
  Widget _buildExpandedCard(String word) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFE8D5C4), // Soft Peach/Tan from Figma
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Word Title
          Text(
            _capitalize(word),
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),

          // Content Area (Loading, Story, or Results)
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator(color: Colors.black87)),
            )
          else if (_analysisResult != null)
            _buildResultView(word)
          else if (_practiceText != null)
              _buildStoryView(),
        ],
      ),
    );
  }

  // 2A. EXPANDED SUB-VIEW: The Story & Mic Button
  Widget _buildStoryView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _practiceText!,
          style: const TextStyle(
            fontSize: 16,
            height: 1.6,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 24),

        // Bottom Right Controls
        Align(
          alignment: Alignment.centerRight,
          child: _audioPath != null && !_isRecording
              ? ElevatedButton(
            onPressed: _isAnalyzing ? null : _analyzeReview,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF333333),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
            child: _isAnalyzing
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text("ANALYZE", style: TextStyle(fontWeight: FontWeight.bold)),
          )
              : GestureDetector(
            onTap: _toggleRecording,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 70,
              height: 45,
              decoration: BoxDecoration(
                color: _isRecording ? Colors.red : const Color(0xFF3B3B3B), // Dark Charcoal Mic Button
                borderRadius: BorderRadius.circular(24),
              ),
              child: Center(
                child: Icon(
                  _isRecording ? Icons.stop_rounded : Icons.mic_none_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // 2B. EXPANDED SUB-VIEW: The Results & Action Buttons
  Widget _buildResultView(String word) {
    return Column(
      children: [
        DetailedResultView(
          overallScore: double.tryParse((_analysisResult?['quality_scores']?['overall_score'] ?? "0").toString()) ?? 0,
          fluency: double.tryParse((_analysisResult?['quality_scores']?['fluency'] ?? "0").toString()) ?? 0,
          pronunciation: double.tryParse((_analysisResult?['quality_scores']?['pronunciation'] ?? "0").toString()) ?? 0,
          clarity: double.tryParse((_analysisResult?['quality_scores']?['clarity'] ?? "0").toString()) ?? 0,
          accuracy: double.tryParse((_analysisResult?['transcription_metrics']?['accuracy_from_wer'] ?? "0").toString().replaceAll('%', '')) ?? 0,
          wpm: double.tryParse((_analysisResult?['transcription_metrics']?['words_per_minute'] ?? "0").toString()) ?? 0,
          ageGroup: _analysisResult?['speaker_analysis']?['predicted_age_group'] ?? "?",
          wordAnalysis: _analysisResult?['word_analysis'] ?? [],
          userTranscription: _analysisResult?['full_transcription'] ?? "",
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    _analysisResult = null;
                    _audioPath = null;
                    _isRecording = false;
                    _isAnalyzing = false;
                  });
                },
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: const Color(0xFF3B3B3B), // Dark Grey
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                child: const Text("RETRY", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () => _submitMastery(word),
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: const Color(0xFF5AB664), // Green
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                child: const Text("SUBMIT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // --- HELPER METHODS ---

  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  Future<void> _submitMastery(String word) async {
    double score = double.tryParse((_analysisResult?['quality_scores']?['overall_score'] ?? "0").toString()) ?? 0;

    if (score >= 70) {
      // Permanently remove from the 'users' collection
      await FirebaseFirestore.instance.collection('users').doc(widget.studentId).update({
        'mistake_words': FieldValue.arrayRemove([word]),
      });

      if (mounted) {
        setState(() {
          _currentMistakeWords.remove(word);
          _selectedWord = null;
          _practiceText = null;
          _analysisResult = null;
          _audioPath = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Mastered! Removed from list. 🎉"), backgroundColor: Colors.green),
        );
      }
    } else {
      // If score is too low, just collapse it or show a message
      setState(() {
        _selectedWord = null;
        _practiceText = null;
        _analysisResult = null;
        _audioPath = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Keep practicing! Score must be 70+ to master."), backgroundColor: Colors.orange),
      );
    }
  }
}