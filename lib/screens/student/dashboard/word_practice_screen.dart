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
    // Initialize the local list from the data passed via constructor
    _currentMistakeWords = List.from(widget.mistakeWords);
  }

  void _selectWord(String word) {
    setState(() {
      _selectedWord = word;
      _practiceText = null; 
      _analysisResult = null;
      _audioPath = null;
    });
  }

  Future<void> _generatePractice() async {
    if (_selectedWord == null) return;
    
    setState(() {
      _isLoading = true;
      _analysisResult = null; 
    });

    final text = await _practiceApi.generatePractice(
      sentence: "", 
      weakArea: _selectedWord! 
    );
    
    if (mounted) {
      setState(() {
        _practiceText = text.isNotEmpty ? text : "Let's practice the word $_selectedWord.";
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleRecording() async {
    try {
      if (_isRecording) {
        final path = await _audioRecorder.stop();
        setState(() { _isRecording = false; _audioPath = path; });
      } else {
        if (await _audioRecorder.hasPermission()) {
          final Directory appDir = await getApplicationDocumentsDirectory();
          // Use .wav for better backend compatibility
          final String filePath = '${appDir.path}/rec_${DateTime.now().millisecondsSinceEpoch}.wav';

          const config = RecordConfig(
            encoder: AudioEncoder.wav,
            sampleRate: 16000, 
            numChannels: 1,
          );

          await _audioRecorder.start(config, path: filePath);
          setState(() { _isRecording = true; _analysisResult = null; });
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
      setState(() { _analysisResult = response; _isAnalyzing = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Mastery Hub"),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 20, left: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text("Pick a word to master:", 
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
            ),
          ),
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
              itemCount: _currentMistakeWords.length, 
              itemBuilder: (context, index) {
                final word = _currentMistakeWords[index]; 
                bool isSelected = _selectedWord == word;
                return GestureDetector(
                  onTap: () => _selectWord(word),
                  child: Container(
                    width: 120,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.orange : Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: isSelected ? Colors.orange : Colors.orange.shade100),
                    ),
                    child: Center(
                      child: Text(
                        word.toUpperCase(),
                        style: TextStyle(
                          fontWeight: FontWeight.bold, 
                          color: isSelected ? Colors.white : Colors.orange.shade700
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const Divider(),
          Expanded(
            child: _selectedWord == null
                ? const Center(child: Text("Tap a word above to start!"))
                : _buildPracticeArea(),
          ),
        ],
      ),
    );
  }

  Widget _buildPracticeArea() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_practiceText == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.auto_awesome, size: 50, color: Colors.orange),
            const SizedBox(height: 15),
            Text("Ready to master '${_selectedWord!.toUpperCase()}'?", 
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _generatePractice,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: const Text("GENERATE STORY", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          if (_analysisResult == null) ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Text(_practiceText!, 
                style: const TextStyle(fontSize: 18, height: 1.6, fontStyle: FontStyle.italic),
                textAlign: TextAlign.center),
            ),
            const Spacer(),
            GestureDetector(
              onTap: _toggleRecording,
              child: CircleAvatar(
                radius: 40,
                backgroundColor: _isRecording ? Colors.red : Colors.blue,
                child: Icon(_isRecording ? Icons.stop : Icons.mic, color: Colors.white, size: 35),
              ),
            ),
            const SizedBox(height: 20),
            if (_audioPath != null && !_isRecording)
              ElevatedButton(
                onPressed: _isAnalyzing ? null : _analyzeReview,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                child: _isAnalyzing ? const CircularProgressIndicator(color: Colors.white) : const Text("ANALYZE REVIEW"),
              ),
          ],
          if (_analysisResult != null)
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: DetailedResultView(
                        overallScore: double.tryParse((_analysisResult?['quality_scores']?['overall_score'] ?? "0").toString()) ?? 0,
                        fluency: double.tryParse((_analysisResult?['quality_scores']?['fluency'] ?? "0").toString()) ?? 0,
                        pronunciation: double.tryParse((_analysisResult?['quality_scores']?['pronunciation'] ?? "0").toString()) ?? 0,
                        clarity: double.tryParse((_analysisResult?['quality_scores']?['clarity'] ?? "0").toString()) ?? 0,
                        accuracy: double.tryParse((_analysisResult?['transcription_metrics']?['accuracy_from_wer'] ?? "0")
                            .toString().replaceAll('%','')) ?? 0,
                        wpm: double.tryParse((_analysisResult?['transcription_metrics']?['words_per_minute'] ?? "0").toString()) ?? 0,
                        ageGroup: _analysisResult?['speaker_analysis']?['predicted_age_group'] ?? "?",
                        wordAnalysis: _analysisResult?['word_analysis'] ?? [],
                        userTranscription: _analysisResult?['full_transcription'] ?? "",
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _analysisResult = null;
                            _audioPath = null;
                            _isRecording = false;
                            _isAnalyzing = false;
                          });
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text("Retry"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () async {
                          double score = double.tryParse((_analysisResult?['quality_scores']?['overall_score'] ?? "0").toString()) ?? 0;

                          if (score >= 70) {
                            // Permanently remove from the 'users' collection
                            await FirebaseFirestore.instance
                                .collection('users')
                                .doc(widget.studentId)
                                .update({
                              'mistake_words': FieldValue.arrayRemove([_selectedWord]),
                            });

                            if (mounted) {
                              setState(() {
                                // Update local state for immediate tile removal
                                _currentMistakeWords.remove(_selectedWord); 
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Mastered! Removed from list."), backgroundColor: Colors.green),
                                );
                              });
                            }
                          }

                          setState(() {
                            _selectedWord = null;
                            _practiceText = null;
                            _analysisResult = null;
                            _audioPath = null;
                          });
                        },
                        icon: const Icon(Icons.check),
                        label: const Text("Submit"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            )
        ],
      ),
    );
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    super.dispose();
  }
}