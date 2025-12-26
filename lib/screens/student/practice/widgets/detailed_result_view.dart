import 'package:flutter/material.dart';

class DetailedResultView extends StatelessWidget {
  final double overallScore;
  final double fluency;
  final double pronunciation;
  final double clarity;
  final double accuracy;
  final double wpm;
  final String ageGroup;
  final List<dynamic> wordAnalysis;

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
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. OVERALL SCORE CIRCLE
        Center(
          child: Column(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    height: 120, width: 120,
                    child: CircularProgressIndicator(
                      value: overallScore / 100,
                      strokeWidth: 10,
                      backgroundColor: Colors.grey.shade200,
                      color: _getScoreColor(overallScore),
                    ),
                  ),
                  Text("${overallScore.round()}%", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: _getScoreColor(overallScore))),
                ],
              ),
              const SizedBox(height: 10),
              const Text("Overall Performance", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
        ),
        const SizedBox(height: 25),

        // 2. METRICS GRID
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: [
            _buildMetricCard("Fluency", fluency.toStringAsFixed(1), Icons.waves, Colors.blue),
            _buildMetricCard("Pronunciation", pronunciation.toStringAsFixed(1), Icons.record_voice_over, Colors.purple),
            _buildMetricCard("Clarity", "${clarity.toStringAsFixed(0)}%", Icons.hearing, Colors.orange),
            _buildMetricCard("Speed", "${wpm.toStringAsFixed(0)} wpm", Icons.speed, Colors.red),
            _buildMetricCard("Accuracy", "${accuracy.toStringAsFixed(0)}%", Icons.check_circle_outline, Colors.green),
            _buildMetricCard("Age Group", ageGroup, Icons.face, Colors.teal),
          ],
        ),

        const SizedBox(height: 25),

        // 3. DETAILED FEEDBACK
        const Text("📝 Word-by-Word Feedback:", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: _buildRichTextTranscription(wordAnalysis),
        ),

        // 4. LEGEND
        const SizedBox(height: 10),
        const Wrap(
          spacing: 15,
          children: [
            Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.circle, color: Colors.green, size: 12), SizedBox(width: 5), Text("Perfect")]),
            Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.circle, color: Colors.red, size: 12), SizedBox(width: 5), Text("Mistake")]),
            Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.circle, color: Colors.grey, size: 12), SizedBox(width: 5), Text("Skipped")]),
          ],
        )
      ],
    );
  }

  // --- HELPER WIDGETS ---

  Widget _buildMetricCard(String label, String value, IconData icon, Color color) {
    return Container(
      width: 100, // Fixed width for consistent grid
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: color), textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Color _getScoreColor(double score) => score >= 80 ? Colors.green : (score >= 50 ? Colors.orange : Colors.red);

  Widget _buildRichTextTranscription(List<dynamic> words) {
    if (words.isEmpty) return const Text("No details available.");

    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 18, height: 1.5, color: Colors.black),
        children: words.map((w) {
          var word = w as Map<String, dynamic>;
          Color color = Colors.black;
          TextDecoration decoration = TextDecoration.none;
          Color? bg;

          switch (word['color']) {
            case 'green': color = Colors.green.shade700; break;
            case 'red':
              color = Colors.red.shade700;
              bg = Colors.red.shade50;
              break;
            case 'gray':
              color = Colors.grey;
              decoration = TextDecoration.lineThrough;
              break;
          }

          return TextSpan(
            text: "${word['text']} ",
            style: TextStyle(color: color, backgroundColor: bg, decoration: decoration, fontWeight: word['color'] == 'green' ? FontWeight.bold : FontWeight.normal),
          );
        }).toList(),
      ),
    );
  }
}