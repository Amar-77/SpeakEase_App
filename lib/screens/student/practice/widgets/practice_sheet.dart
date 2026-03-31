import 'dart:io';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:speakease/services/api_service.dart';
import 'package:speakease/services/gamification_service.dart';
import 'detailed_result_view.dart';

// =============================================================================
// 🎯 TUNING BLOCK 1 — IDLE avatar
//    Adjust ONLY these values for the idle state character
// =============================================================================
const double _kIdleHeight  = 420;   // px — character height
const double _kIdleWidth   = 420;   // px — character width
const double _kIdleBottom  = -70;   // px — lift up from zone bottom (0 = floor)
const double _kIdleShiftX  = 10;     // px — shift from centre (+ right, - left)

// =============================================================================
// 🎯 TUNING BLOCK 2 — RECORDING avatar
//    Adjust ONLY these values for the listening state character
// =============================================================================
const double _kListenHeight = 680;
const double _kListenWidth  = 680;
const double _kListenBottom = -210;
const double _kListenShiftX = 45;

// =============================================================================
// 🎯 TUNING BLOCK 3 — PROCESSING/SPEAKING avatar
//    Adjust ONLY these values for the thinking state character
// =============================================================================
const double _kThinkHeight  = 410;
const double _kThinkWidth   = 410;
const double _kThinkBottom  = -100;
const double _kThinkShiftX  = 130;
// =============================================================================

enum _AvatarState { idle, recording, processing }

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

  // --- SUBMIT FUNCTION ---
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

      // ⏱️ DURATION
      double durationVal = double.tryParse(_analysisResult?['audio_duration']?.toString() ?? "30") ?? 30.0;
      int durationInSeconds = durationVal.round();

      List<dynamic> words = _analysisResult!['word_analysis'] ?? [];
      List<String> redWords = words
          .where((w) => w['color'] == 'red')
          .map((w) => w['text'].toString().toLowerCase())
          .toList();

      // 🏆 GAMIFICATION CALL
      await _gamificationService.processSubmission(
        userId: widget.studentId,
        baseCoins: widget.basePoints,
        accuracyScore: overall.round(),
        durationSeconds: durationInSeconds,
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

  // =========================================================================
  // AVATAR STATE LOGIC
  // =========================================================================

  _AvatarState get _currentAvatarState {
    if (_isRecording) return _AvatarState.recording;
    if (_isAnalyzing || _isSpeaking) return _AvatarState.processing;
    return _AvatarState.idle;
  }

  ({String asset, double h, double w, double bottom, double shiftX})
  get _avatarConfig {
    switch (_currentAvatarState) {
      case _AvatarState.recording:
        return (
        asset:  'assets/images/kid_hearing.png',
        h:      _kListenHeight,
        w:      _kListenWidth,
        bottom: _kListenBottom,
        shiftX: _kListenShiftX,
        );
      case _AvatarState.processing:
        return (
        asset:  'assets/images/kid_with_mic_on_assignment.png',
        h:      _kThinkHeight,
        w:      _kThinkWidth,
        bottom: _kThinkBottom,
        shiftX: _kThinkShiftX,
        );
      case _AvatarState.idle:
      default:
        return (
        asset:  'assets/images/kidbeforetts.png',
        h:      _kIdleHeight,
        w:      _kIdleWidth,
        bottom: _kIdleBottom,
        shiftX: _kIdleShiftX,
        );
    }
  }

  // =========================================================================
  // BUILD METHOD
  // =========================================================================

  @override
  Widget build(BuildContext context) {
    final cfg = _avatarConfig; // Get current tuning values

    return Container(
      padding: const EdgeInsets.only(top: 24, left: 24, right: 24, bottom: 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          // ── 1. Top Bar (Close Button) ──
          Align(
            alignment: Alignment.topRight,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: const Icon(Icons.close, color: Colors.black87),
            ),
          ),

          // ── 2. Content (Avatar + Scrollable Text) ──
          Expanded(
            child: _analysisResult != null

            // ================= RESULT VIEW =================
                ? SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
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
                Row(children:[
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _retry,
                      style: ElevatedButton.styleFrom(
                        elevation: 0, // Flat look like the design
                        backgroundColor: const Color(0xFF424242), // Dark grey
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24), // Pill shape
                        ),
                      ),
                      child: const Text(
                        "RETRY",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _submitResults,
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: const Color(0xFF7DD3F7), // Light blue
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: const Text(
                        "SUBMIT",
                        style: TextStyle(
                          color: Colors.black87, // Dark text on light blue
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ])
              ]),
            )

            // ================= RECORDING UI =================
                : Column(
              children: [
                // 🧑‍🏫 Adjustable Avatar (Speaky Style)
                SizedBox(
                  height: 280, // Base zone height for the avatar to exist in
                  child: LayoutBuilder(
                    builder: (ctx, constraints) {
                      final double centreX = (constraints.maxWidth - cfg.w) / 2 + cfg.shiftX;
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            bottom: cfg.bottom,
                            left: centreX,
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 0),
                              transitionBuilder: (child, anim) =>
                                  FadeTransition(opacity: anim, child: child),
                              child: Image.asset(
                                cfg.asset,
                                key: ValueKey(cfg.asset),
                                height: cfg.h,
                                width: cfg.w,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),

                const SizedBox(height: 16),
// 📖 Scrollable Text Area
                Expanded(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F2F2),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    // 1. Add LayoutBuilder to get the available height of the grey box
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          // 2. Add ConstrainedBox to force a minimum height
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: constraints.maxHeight,
                            ),
                            // 3. Wrap your Text in a Center widget
                            child: Center(
                              child: Text(
                                widget.referenceText,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 20,
                                  height: 1.5,
                                  color: _isSpeaking ? Colors.red.shade700 : Colors.black87,
                                  fontStyle: _isSpeaking ? FontStyle.italic : FontStyle.normal,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── 3. Bottom Buttons (Fixed at bottom) ──
          if (_analysisResult == null) ...[
            const SizedBox(height: 24),

            // Analyze Button
            if (_audioPath != null && !_isRecording) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isAnalyzing ? null : _analyze,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  child: _isAnalyzing
                      ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text("ANALYZE RECORDING",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Speaker & Mic Row
            Row(
              children: [
                // 🔊 SPEAKER BUTTON
                Expanded(
                  child: GestureDetector(
                    onTap: (!_isRecording && !_isSpeaking) ? _playTeacherVoice : null,
                    child: Container(
                      height: 64,
                      decoration: BoxDecoration(
                        color: _isSpeaking ? Colors.orange : const Color(0xFF4A4A4A),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Center(
                        child: _isLoadingTTS
                            ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : SvgPicture.asset(
                          'assets/icons/speaker_icon.svg',
                          width: 28,
                          height: 28,
                          colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 16),

                // 🎤 MIC BUTTON
                Expanded(
                  child: GestureDetector(
                    onTap: _isSpeaking ? null : _toggleRecording,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: 64,
                      decoration: BoxDecoration(
                        color: _isRecording ? const Color(0xFFFF4B4B) : const Color(0xFF6BC96C),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Center(
                        child: _isRecording
                            ? Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        )
                            : SvgPicture.asset(
                          'assets/icons/mic.svg',
                          width: 28,
                          height: 28,
                          colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}