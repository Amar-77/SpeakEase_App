import 'package:flutter/material.dart';

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
    // Even though server fixes it, we double-check here to prevent UI crashes.
    if (serverOverall > 10.0) serverOverall = 10.0;
    if (fluency > 10.0) fluency = 10.0;
    if (pronunciation > 10.0) pronunciation = 10.0;
    if (accuracy > 10.0) accuracy = 10.0;

    // 3. PROGRESS VALUE (0.0 to 1.0 for the Circle)
    double progressValue = serverOverall / 10.0;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Session Report"),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        titleTextStyle: const TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 10),

            // 1. THE BIG SCORE CIRCLE (Weighted Overall)
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  height: 180, width: 180,
                  child: CircularProgressIndicator(
                    value: progressValue, // 0.0 to 1.0
                    strokeWidth: 15,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      serverOverall > 7 ? Colors.green : (serverOverall > 4 ? Colors.orange : Colors.red),
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "${(serverOverall * 10).toInt()}%", // Show as Percentage
                      style: const TextStyle(fontSize: 42, fontWeight: FontWeight.bold),
                    ),
                    const Text("Overall Score", style: TextStyle(color: Colors.grey, fontSize: 14)),
                  ],
                )
              ],
            ),
            const SizedBox(height: 30),

            // 2. THE 3 METRICS (Fluency, Pronunciation, Clarity)
            Row(
              children: [
                _buildScoreCard("Fluency", fluency, Colors.blue),
                const SizedBox(width: 8),
                _buildScoreCard("Pronun.", pronunciation, Colors.purple),
                const SizedBox(width: 8),
                _buildScoreCard("Clarity", accuracy, Colors.teal),
              ],
            ),

            const SizedBox(height: 30),

            // 3. SUMMARY TEXT
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.analytics_outlined, color: Colors.grey),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Great job! You practiced $turns sentences. Your clarity score is ${accuracy.toStringAsFixed(1)}/10.",
                      style: const TextStyle(fontSize: 15, color: Colors.black87),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // 4. BACK BUTTON
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  elevation: 2,
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

  // Helper Widget for the small cards
  Widget _buildScoreCard(String title, double score, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        ),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Text(
              score.toStringAsFixed(1),
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color),
            ),
            Text("/10", style: TextStyle(fontSize: 10, color: color.withOpacity(0.7))),
          ],
        ),
      ),
    );
  }
}