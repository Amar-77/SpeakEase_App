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
import 'package:flutter_svg/flutter_svg.dart';

import 'report_card_screen.dart';

// =============================================================================
// 🎯 TUNING BLOCK 1 — IDLE avatar (kid_with_mic_on_assignment.png)
//    Adjust ONLY these values for the idle state character
// =============================================================================
const double _kIdleHeight  = 520;   // px — character height
const double _kIdleWidth   = 520;   // px — character width
const double _kIdleBottom  = -90;     // px — lift up from zone bottom (0 = floor)
const double _kIdleShiftX  = 140;     // px — shift from centre (+ right, - left)

// =============================================================================
// 🎯 TUNING BLOCK 2 — RECORDING avatar (kid_hearing.png)
//    Adjust ONLY these values for the listening state character
// =============================================================================
const double _kListenHeight = 950;
const double _kListenWidth  = 950;
const double _kListenBottom = -290;
const double _kListenShiftX = 50;

// =============================================================================
// 🎯 TUNING BLOCK 3 — PROCESSING avatar (thinking_speaky.png)
//    Adjust ONLY these values for the thinking state character
// =============================================================================
const double _kThinkHeight  = 1020;
const double _kThinkWidth   = 1020;
const double _kThinkBottom  = -340;
const double _kThinkShiftX  = 260;

// =============================================================================
// 🎯 BUBBLE TUNING — resize the speech bubble PNG
// =============================================================================
const double _kBubbleWidth   = double.infinity; // or a fixed px like 340
const double _kBubbleHeight  = 250;             // px — increase for taller bubble
// Text padding inside the bubble (tweak if text overflows or sits wrong)
const EdgeInsets _kBubbleTextPadding =
EdgeInsets.fromLTRB(28, 22, 48, 50); // left, top, right, bottom
// =============================================================================

enum _SpeakyState { idle, recording, processing }

class SpeakyChatScreen extends StatefulWidget {
  const SpeakyChatScreen({Key? key}) : super(key: key);

  @override
  State<SpeakyChatScreen> createState() => _SpeakyChatScreenState();
}

class _SpeakyChatScreenState extends State<SpeakyChatScreen> {
  final String? baseUrl = dotenv.env['API_URL'];

  late String sessionId;
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer   _player   = AudioPlayer();

  List<Map<String, String>> chatHistory = [];
  _SpeakyState _speakyState = _SpeakyState.idle;

  int       turnCount = 0;
  final int maxTurns  = 5;

  String _bubbleText   = "Hi! I'm Speaky. What do you want to talk about today?";
  bool   _bubbleIsUser = false; // false = AI black bold / true = user blue-purple

  @override
  void initState() {
    super.initState();
    sessionId = const Uuid().v4();
  }

  @override
  void dispose() {
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }

  // ── 1. RECORDING ──────────────────────────────────────────────────────────
  Future<void> _startRecording() async {
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Microphone permission required!")));
      }
      return;
    }
    final dir = await getTemporaryDirectory();
    await _recorder.start(const RecordConfig(),
        path: '${dir.path}/temp_voice.wav');
    setState(() => _speakyState = _SpeakyState.recording);
  }

  Future<void> _stopRecording() async {
    final path = await _recorder.stop();
    if (path != null) {
      await _sendAudioTurn(path);
    } else {
      setState(() => _speakyState = _SpeakyState.idle);
    }
  }

  // ── 2. SEND TO SERVER ─────────────────────────────────────────────────────
  Future<void> _sendAudioTurn(String audioPath) async {
    setState(() => _speakyState = _SpeakyState.processing);

    try {
      final uri     = Uri.parse('$baseUrl/chat-batch/');
      final request = http.MultipartRequest('POST', uri);
      request.files.add(await http.MultipartFile.fromPath('file', audioPath));
      request.fields['session_id']   = sessionId;
      request.fields['chat_history'] = jsonEncode(chatHistory);

      final response =
      await http.Response.fromStream(await request.send());

      if (response.statusCode == 200) {
        final userText = response.headers['x-user-text'] ?? '...';
        final aiText   = response.headers['x-ai-text']   ?? '...';

        setState(() {
          _bubbleText   = userText;
          _bubbleIsUser = true;
        });

        chatHistory
          ..add({"role": "user", "content": userText})
          ..add({"role": "ai",   "content": aiText});
        turnCount++;

        final dir  = await getTemporaryDirectory();
        final file = File('${dir.path}/response.mp3');
        await file.writeAsBytes(response.bodyBytes);
        await _player.play(DeviceFileSource(file.path));

        if (mounted) {
          setState(() {
            _bubbleText   = aiText;
            _bubbleIsUser = false;
            _speakyState  = _SpeakyState.idle;
          });
        }

        if (turnCount >= maxTurns) {
          await Future.delayed(const Duration(seconds: 4));
          if (mounted) _finishSessionAndShowReport();
        }
      } else {
        if (mounted) setState(() => _speakyState = _SpeakyState.idle);
      }
    } catch (e) {
      debugPrint("Network Error: $e");
      if (mounted) setState(() => _speakyState = _SpeakyState.idle);
    }
  }

  // ── 3. END SESSION ────────────────────────────────────────────────────────
  Future<void> _finishSessionAndShowReport() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final response =
      await http.get(Uri.parse('$baseUrl/end-session-score/$sessionId'));
      if (mounted) Navigator.pop(context);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          Navigator.pushReplacement(context,
              MaterialPageRoute(builder: (_) => ReportCardScreen(data: data)));
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Failed to generate report.")));
        }
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      debugPrint("Report Error: $e");
    }
  }

  // ── helpers ───────────────────────────────────────────────────────────────
  String get _statusLabel {
    switch (_speakyState) {
      case _SpeakyState.recording:  return 'Listening......';
      case _SpeakyState.processing: return 'Thinking......';
      case _SpeakyState.idle:
      default:                      return 'Respond after listening';
    }
  }

  // Returns the per-state avatar config as a record
  ({String asset, double h, double w, double bottom, double shiftX})
  get _avatarConfig {
    switch (_speakyState) {
      case _SpeakyState.recording:
        return (
        asset:  'assets/images/kid_hearing.png',
        h:      _kListenHeight,
        w:      _kListenWidth,
        bottom: _kListenBottom,
        shiftX: _kListenShiftX,
        );
      case _SpeakyState.processing:
        return (
        asset:  'assets/images/thinking_speaky.png',
        h:      _kThinkHeight,
        w:      _kThinkWidth,
        bottom: _kThinkBottom,
        shiftX: _kThinkShiftX,
        );
      case _SpeakyState.idle:
      default:
        return (
        asset:  'assets/images/kid_with_mic_on_assignment.png',
        h:      _kIdleHeight,
        w:      _kIdleWidth,
        bottom: _kIdleBottom,
        shiftX: _kIdleShiftX,
        );
    }
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final cfg = _avatarConfig;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor:  Colors.white,
        surfaceTintColor: Colors.white,
        elevation:        0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: Colors.black, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Speaky',
          style: TextStyle(
              color: Colors.black,
              fontSize: 22,
              fontWeight: FontWeight.bold),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: _finishSessionAndShowReport,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$turnCount/$maxTurns',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.black54),
                ),
              ),
            ),
          ),
        ],
      ),

      body: Column(
        children: [
          // ── UPPER: bubble + avatar + label ──────────────────────────────
          Expanded(
            child: Column(
              children: [
                const SizedBox(height: 8),

                // ── SPEECH BUBBLE PNG with text stacked on top ─────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _SpeechBubble(
                    text:   _bubbleText,
                    isUser: _bubbleIsUser,
                  ),
                ),

                // ── AVATAR — each state has its OWN position + size ────────
                Expanded(
                  child: LayoutBuilder(
                    builder: (ctx, constraints) {
                      final double centreX =
                          (constraints.maxWidth - cfg.w) / 2 + cfg.shiftX;
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            bottom: cfg.bottom,
                            left:   centreX,
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 0),
                              transitionBuilder: (child, anim) =>
                                  FadeTransition(opacity: anim, child: child),
                              child: Image.asset(
                                cfg.asset,
                                key:    ValueKey(cfg.asset),
                                height: cfg.h,
                                width:  cfg.w,
                                fit:    BoxFit.contain,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),

                // ── STATUS LABEL ───────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: Text(
                      _statusLabel,
                      key: ValueKey(_statusLabel),
                      style: TextStyle(
                        fontSize:   14,
                        color:      Colors.grey.shade500,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── MIC BUTTON ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(40, 0, 40, 36),
            child: _MicButton(
              speakyState:    _speakyState,
              onIdleTap:      _startRecording,
              onRecordingTap: _stopRecording,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// SPEECH BUBBLE — uses YOUR exported PNG as the background
// Text is stacked on top using padding to sit inside the blob area
// =============================================================================
class _SpeechBubble extends StatelessWidget {
  final String text;
  final bool   isUser;

  const _SpeechBubble({required this.text, required this.isUser});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width:  _kBubbleWidth == double.infinity
          ? double.infinity
          : _kBubbleWidth,
      height: _kBubbleHeight,
      child: Stack(
        children: [
          // ── 1. YOUR custom bubble PNG fills the box ──────────────────────
          // The PNG has a black background — use colorBlendMode to knock it out,
          // OR (simpler) make the PNG transparent-bg in your editor and re-export.
          // For now we use the PNG as-is and clip a matching shape behind text.
          Positioned.fill(
            child: Image.asset(
              'assets/images/text_box_custom.png',
              fit: BoxFit.fill,
            ),
          ),

          // ── 2. Text sits on top, padded to stay inside the grey blob ─────
          // _kBubbleTextPadding controls exactly where text sits in the blob.
          // Increase bottom padding to avoid the tail area.
          Positioned.fill(
            child: Padding(
              padding: _kBubbleTextPadding,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                child: Text(
                  text,
                  key:       ValueKey(text),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize:   17,
                    fontWeight: isUser ? FontWeight.w500 : FontWeight.bold,
                    color:      isUser
                        ? const Color(0xFF6C7FD8)
                        : Colors.black,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MicButton extends StatelessWidget {
  final _SpeakyState speakyState;
  final VoidCallback onIdleTap;
  final VoidCallback onRecordingTap;

  const _MicButton({
    required this.speakyState,
    required this.onIdleTap,
    required this.onRecordingTap,
  });

  @override
  Widget build(BuildContext context) {
    late final Color bgColor;
    late final Widget icon;
    late final VoidCallback? onTap;

    switch (speakyState) {
      case _SpeakyState.recording:
        bgColor = const Color(0xFFEF4444);

        icon = Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
          ),
        );

        onTap = onRecordingTap;
        break;

      case _SpeakyState.processing:
        bgColor = const Color(0xFF9E9E9E);

        icon = SvgPicture.asset(
          'assets/icons/mic.svg',
          width: 24,
          height: 24,
          colorFilter: const ColorFilter.mode(
            Colors.white,
            BlendMode.srcIn,
          ),
        );

        onTap = null;
        break;

      case _SpeakyState.idle:
      default:
        bgColor = const Color(0xFF66BB6A);

        icon = SvgPicture.asset(
          'assets/icons/mic.svg',
          width: 24,
          height: 24,
          colorFilter: const ColorFilter.mode(
            Colors.white,
            BlendMode.srcIn,
          ),
        );

        onTap = onIdleTap;
    }

    return Center(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          width: 140,
          height: 60,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(30),
            boxShadow: onTap != null
                ? [
              BoxShadow(
                color: bgColor.withOpacity(0.35),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ]
                : [],
          ),
          child: Center(child: icon),
        ),
      ),
    );
  }
}