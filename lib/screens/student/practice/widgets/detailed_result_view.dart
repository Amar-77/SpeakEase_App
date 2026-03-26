import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'dart:math'; // Required for CustomPainter math

class DetailedResultView extends StatelessWidget {
  final double overallScore;
  final double fluency;
  final double pronunciation;
  final double clarity;
  final double accuracy;
  final double wpm;
  final String ageGroup;
  final List<dynamic> wordAnalysis;
  final String userTranscription;

  const DetailedResultView({
    super.key,
    required this.overallScore,
    required this.fluency,
    required this.pronunciation,
    required this.clarity,
    required this.accuracy,
    required this.wpm,
    required this.ageGroup,
    required this.wordAnalysis,
    required this.userTranscription,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. OVERALL SCORE CIRCLE (Custom Drawn Thick Ring)
        Center(
          child: Column(
            children: [
              // Added padding around the stack to ensure the shadow doesn't get clipped
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: SizedBox(
                  width: 140,
                  height: 140,
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none, // Prevents chopping of the shadow
                    children: [
                      // Donut Shadow Effect
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                      ),
                      // White center mask
                      Container(
                        width: 90,
                        height: 90,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                      // 🌟 Custom Painted Thick Progress Ring
                      SizedBox(
                        width: 140,
                        height: 140,
                        child: CustomPaint(
                          painter: _ThickProgressPainter(
                            progress: overallScore / 100,
                            trackColor: const Color(0xFFE2E2E2), // Light grey
                            progressColor: const Color(0xFF5AB664), // Vibrant green
                            strokeWidth: 26, // Extremely thick, matching design
                          ),
                        ),
                      ),
                      // Large Text
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: "${overallScore.round()}",
                              style: const TextStyle(
                                fontSize: 36, // Slightly larger for balance
                                fontWeight: FontWeight.w900,
                                color: Colors.black87,
                              ),
                            ),
                            const TextSpan(
                              text: "%",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Text("Overall Performance",
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.black87)),
            ],
          ),
        ),
        const SizedBox(height: 30),

        // 2. METRICS GRID (Pastel Squares)
        LayoutBuilder(
            builder: (context, constraints) {
              // Calculate a perfect 3-column square grid
              final double gap = 12.0;
              final double size = (constraints.maxWidth - (gap * 2)) / 3;

              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  _buildPastelCard("Fluency", fluency.toStringAsFixed(1), Icons.waves, const Color(0xFFC7F0FF), size), // Light Blue
                  _buildPastelCard("Pronunciation", pronunciation.toStringAsFixed(1), Icons.record_voice_over, const Color(0xFFE0D4FF), size), // Light Purple
                  _buildPastelCard("Clarity", "${clarity.toStringAsFixed(0)}", Icons.hearing, const Color(0xFFFFF4B8), size), // Light Yellow
                  _buildPastelCard("Speed", "${wpm.toStringAsFixed(0)}wpm", Icons.speed, const Color(0xFFFFBDBD), size), // Light Red/Pink
                  _buildPastelCard("Accuracy", "${accuracy.toStringAsFixed(0)}%", Icons.check_circle_outline, const Color(0xFFB5FFD9), size), // Light Green
                  _buildPastelCard("Age Group", ageGroup, Icons.accessibility_new, const Color(0xFFAFD5FF), size), // Solid Blue
                ],
              );
            }
        ),

        const SizedBox(height: 30),

        // 3. DETAILED FEEDBACK
        const Text("Word-by-Word Feedback:", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFEEEEEE), // Light grey pill
            borderRadius: BorderRadius.circular(30),
          ),
          child: _buildRichTextTranscription(context, wordAnalysis),
        ),

        const SizedBox(height: 20),

        // 4. PERSISTENT TRANSCRIPTION VIEW
        if (userTranscription.isNotEmpty) ...[
          const Text("What we heard:", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFDFF4FF), // Soft blue pill
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(
              "\"$userTranscription\"",
              style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic, color: Colors.blue.shade900),
            ),
          ),
        ],

        const SizedBox(height: 20),

        // 5. LEGEND
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _LegendItem(color: Color(0xFF1EA034), label: "Perfect"),
            _LegendItem(color: Color(0xFFF34343), label: "Mistake"),
            _LegendItem(color: Color(0xFF8A8A8A), label: "Skipped"),
            _LegendItem(color: Color(0xFFF6A329), label: "Extra"),
          ],
        ),

        // Add padding at the bottom so elements don't hit the bottom buttons
        const SizedBox(height: 20),
      ],
    );
  }

  // --- HELPER WIDGETS ---

  Widget _buildPastelCard(String label, String value, IconData icon, Color bgColor, double size) {
    String numPart = value;
    String textPart = "";

    if (value.contains(RegExp(r'[a-zA-Z%]'))) {
      numPart = value.replaceAll(RegExp(r'[a-zA-Z%]'), '');
      textPart = value.replaceAll(RegExp(r'[0-9.]'), '');
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.black87, size: 32),
          const SizedBox(height: 6),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: numPart,
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: Colors.black87),
                ),
                if (textPart.isNotEmpty)
                  TextSpan(
                    text: textPart,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black87),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.black54), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildRichTextTranscription(BuildContext context, List<dynamic> words) {
    if (words.isEmpty) return const Text("No details are available.", style: TextStyle(color: Colors.black54));

    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: const TextStyle(fontSize: 18, height: 1.5, color: Colors.black),
        children: words.map((w) {
          var word = w as Map<String, dynamic>;
          Color color = Colors.black;
          TextDecoration decoration = TextDecoration.none;
          TapGestureRecognizer? recognizer;

          switch (word['color']) {
            case 'green':
              color = const Color(0xFF1EA034); // Solid Green
              break;
            case 'red':
              color = const Color(0xFFF34343); // Solid Red
              decoration = TextDecoration.underline;
              if (word['spoken'] != null) {
                recognizer = TapGestureRecognizer()..onTap = () {
                  _showMistakeDialog(context, word['text'] ?? "", word['spoken']);
                };
              }
              break;
            case 'gray':
              color = const Color(0xFF8A8A8A); // Solid Grey
              decoration = TextDecoration.lineThrough;
              break;
            case 'orange':
              color = const Color(0xFFF6A329); // Solid Orange
              break;
          }

          return TextSpan(
            text: "${word['text'] ?? word['spoken']} ",
            recognizer: recognizer,
            style: TextStyle(
              color: color,
              decoration: decoration,
              fontWeight: FontWeight.w600,
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showMistakeDialog(BuildContext context, String expected, String actual) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Pronunciation Check"),
        content: Text("Target: $expected\nYou said: $actual"),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK"))],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.black87),
        ),
      ],
    );
  }
}

// =========================================================================
// 🎨 CUSTOM PAINTER FOR THICK PROGRESS RING
// =========================================================================
class _ThickProgressPainter extends CustomPainter {
  final double progress; // 0.0 to 1.0
  final Color trackColor;
  final Color progressColor;
  final double strokeWidth;

  _ThickProgressPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    // Radius needs to account for half the stroke width so it stays inside bounds
    final radius = (size.width / 2) - (strokeWidth / 2);

    // 1. Draw Background Track (Full Circle)
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius, trackPaint);

    // 2. Draw Progress Arc
    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round; // Gives those nice rounded ends

    // Start at the top (-pi / 2), and sweep based on progress percentage
    final startAngle = -pi / 2;
    final sweepAngle = 2 * pi * progress;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ThickProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.progressColor != progressColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}