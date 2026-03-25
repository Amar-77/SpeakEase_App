import 'package:flutter/material.dart';
import 'dart:math';

class ReportCardScreen extends StatelessWidget {
  final Map<String, dynamic> data;

  const ReportCardScreen({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    // 1. EXTRACT SCORES (Matching Server JSON Keys)
    double serverOverall = (data['overall_score'] ?? 0).toDouble();
    double fluency = (data['overall_fluency'] ?? 0).toDouble();
    double pronunciation = (data['overall_pronunciation'] ?? 0).toDouble();
    double accuracy = (data['overall_accuracy'] ?? 0).toDouble(); // "Clarity"
    final int turns = data['turns_analyzed'] ?? 0;

    // 2. SAFETY CLAMP (Ensure no score exceeds 10.0)
    if (serverOverall > 10.0) serverOverall = 10.0;
    if (fluency > 10.0) fluency = 10.0;
    if (pronunciation > 10.0) pronunciation = 10.0;
    if (accuracy > 10.0) accuracy = 10.0;

    // 3. PROGRESS VALUE (0.0 to 1.0 for the Circle)
    double progressValue = serverOverall / 10.0;
    int percentageScore = (serverOverall * 10).round();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Session Report",
          style: TextStyle(color: Colors.black87, fontSize: 20, fontWeight: FontWeight.w600),
        ),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),

            // 1. THE BIG SCORE CIRCLE (Custom Thick Ring)
            Center(
              child: Column(
                children: [
                  SizedBox(
                    width: 140,
                    height: 140,
                    child: Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        // Donut Shadow
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.12),
                                blurRadius: 15,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                        ),
                        // Mask center
                        Container(
                          width: 90,
                          height: 90,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                        // Custom Painted Thick Ring
                        SizedBox(
                          width: 140,
                          height: 140,
                          child: CustomPaint(
                            painter: _ThickProgressPainter(
                              progress: progressValue,
                              trackColor: const Color(0xFFE2E2E2), // Light grey
                              progressColor: const Color(0xFF5AB664), // Green
                              strokeWidth: 26,
                            ),
                          ),
                        ),
                        // Text inside ring
                        RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: "$percentageScore",
                                style: const TextStyle(
                                  fontSize: 34,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.black87,
                                ),
                              ),
                              const TextSpan(
                                text: "%",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text("Overall Score",
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.black87)),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // 2. METRICS GRID (Pastel Squares)
            LayoutBuilder(
                builder: (context, constraints) {
                  final double gap = 12.0;
                  final double size = (constraints.maxWidth - (gap * 2)) / 3;

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildPastelCard("Fluency", fluency, Icons.waves, const Color(0xFFC7F0FF), size),
                      _buildPastelCard("Pronunciation", pronunciation, Icons.record_voice_over, const Color(0xFFE0D4FF), size),
                      _buildPastelCard("Clarity", accuracy, Icons.hearing, const Color(0xFFFFF4B8), size),
                    ],
                  );
                }
            ),

            const SizedBox(height: 30),

            // 3. SUMMARY TEXT BOX
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              decoration: BoxDecoration(
                color: const Color(0xFFF2F2F2), // Light grey pill
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.assignment_outlined, color: Colors.black54, size: 26),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      "Great job! You practiced $turns sentences.\nYour clarity score is ${accuracy.toStringAsFixed(1)}/10.",
                      style: const TextStyle(fontSize: 13, color: Colors.black87, fontWeight: FontWeight.w500, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // 4. BACK BUTTON (Purple Pill)
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: const Color(0xFF7B52C3), // Purple matching reference
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
                child: const Text(
                  "Back to Dashboard",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  // --- HELPER WIDGETS ---

  Widget _buildPastelCard(String label, double score, IconData icon, Color bgColor, double size) {
    return Container(
      width: size,
      height: size + 10, // Slightly taller to match reference proportions
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.black87, size: 32),
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: score.toStringAsFixed(1),
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: Colors.black87),
                ),
                const TextSpan(
                  text: "/10",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black54),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black54), textAlign: TextAlign.center),
        ],
      ),
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
    final radius = (size.width / 2) - (strokeWidth / 2);

    // 1. Draw Background Track
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
      ..strokeCap = StrokeCap.round;

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