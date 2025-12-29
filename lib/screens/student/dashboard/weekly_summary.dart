import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class WeeklySummaryScreen extends StatelessWidget {
  const WeeklySummaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;
    final DateTime now = DateTime.now();
    // Calculate the threshold for exactly 7 days ago
    final DateTime lastWeek = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 7));
    final Timestamp threshold = Timestamp.fromDate(lastWeek);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Weekly Reflection"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- SECTION 1: PRACTICE CONSISTENCY (From daily_stats) ---
            const Text("Practice Consistency", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            _buildActivityChart(user.uid),

            const SizedBox(height: 30),
            const Divider(),
            const SizedBox(height: 15),

            // --- SECTION 2: PERFORMANCE METRICS (From submissions) ---
            const Text("Performance Metrics", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),

            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('submissions')
                  .where('student_id', isEqualTo: user.uid)
                  .where('submitted_at', isGreaterThanOrEqualTo: threshold)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.red)));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                var docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: Text("No practice sessions found for this week.", style: TextStyle(color: Colors.grey))),
                  );
                }

                // Data Aggregation
                double acc = 0, flu = 0, clar = 0, pron = 0, wpmTotal = 0;
                for (var doc in docs) {
                  var d = doc.data() as Map<String, dynamic>;
                  acc += (d['accuracy_score'] ?? 0).toDouble();
                  flu += (d['fluency_score'] ?? 0).toDouble();
                  clar += (d['clarity_score'] ?? 0).toDouble();
                  pron += (d['pronunciation_score'] ?? 0).toDouble();
                  wpmTotal += (d['wpm'] ?? 0).toDouble();
                }

                int count = docs.length;

                return GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 15,
                  mainAxisSpacing: 15,
                  childAspectRatio: 1.2,
                  children: [
                    _buildStatCard("Avg Accuracy", "${(acc / count).toStringAsFixed(1)}%", Icons.verified, Colors.green),
                    _buildStatCard("Avg Fluency", (flu / count).toStringAsFixed(1), Icons.waves, Colors.blue),
                    _buildStatCard("Pronunciation", (pron / count).toStringAsFixed(1), Icons.record_voice_over, Colors.purple),
                    _buildStatCard("Avg Clarity", "${(clar / count).toStringAsFixed(1)}%", Icons.hearing, Colors.orange),
                    _buildStatCard("Avg WPM", (wpmTotal / count).toStringAsFixed(0), Icons.speed, Colors.red),
                  ],
                );
              },
            ),

            const SizedBox(height: 30),

            // --- SECTION 3: WORDS TO REVIEW (Aggregated from word_analysis) ---
            const Text("Words to Review", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            _buildMistakeWordList(user.uid, threshold),

            const SizedBox(height: 30),

            // --- SECTION 4: COIN SUMMARY ---
            _buildWeeklyCoinSummary(user.uid),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // --- WIDGET: TOP 3 MISTAKE WORD AGGREGATION ---
  Widget _buildMistakeWordList(String uid, Timestamp threshold) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('submissions')
          .where('student_id', isEqualTo: uid)
          .where('submitted_at', isGreaterThanOrEqualTo: threshold)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();

        Map<String, int> mistakeWords = {};

        // Aggregate words from the submissions collection
        for (var doc in snapshot.data!.docs) {
          var data = doc.data() as Map<String, dynamic>;
          // Extract word_analysis array
          List<dynamic> analysis = data['word_analysis'] ?? [];
          for (var word in analysis) {
            // Identify incorrect words marked as red
            if (word['color'] == 'red') {
              String text = word['text'].toString().toLowerCase().trim();
              if (text.isNotEmpty) mistakeWords[text] = (mistakeWords[text] ?? 0) + 1;
            }
          }
        }

        if (mistakeWords.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(15)),
            child: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 10),
                Text("Excellent! No frequent mistakes this week."),
              ],
            ),
          );
        }

        // Sort by frequency and take only the TOP 3
        var sortedMistakes = mistakeWords.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        // Limit the list to top 3
        var topThree = sortedMistakes.take(3).toList();

        return Column(
          children: topThree.map((entry) {
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              color: Colors.red.shade50,
              elevation: 0,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.red.shade100,
                  child: Text("${topThree.indexOf(entry) + 1}",
                      style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                ),
                title: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                subtitle: Text("Mispronounced ${entry.value} times this week"),
                trailing: const Icon(Icons.warning_amber_rounded, color: Colors.red),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  // --- WIDGET: ACTIVITY CHART ---
  Widget _buildActivityChart(String uid) {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('users').doc(uid).collection('daily_stats')
          .orderBy('date', descending: true).limit(7).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()));

        var docs = snapshot.data!.docs;
        Map<String, int> weekData = {"Mon": 0, "Tue": 0, "Wed": 0, "Thu": 0, "Fri": 0, "Sat": 0, "Sun": 0};

        for (var doc in docs) {
          var d = doc.data() as Map<String, dynamic>;
          String dateStr = d['date'] ?? "";
          if (dateStr.isNotEmpty) {
            DateTime dt = DateTime.parse(dateStr);
            String dayName = ["", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"][dt.weekday];
            weekData[dayName] = d['minutes_spent'] ?? 0;
          }
        }

        return Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(15)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"].map((day) => _buildBar(day, weekData[day] ?? 0)).toList(),
          ),
        );
      },
    );
  }

  Widget _buildBar(String day, int mins) {
    double barHeight = (mins * 5.0).clamp(5.0, 100.0);
    return Column(
      children: [
        Text("$mins", style: const TextStyle(fontSize: 10, color: Colors.grey)),
        const SizedBox(height: 4),
        Container(width: 12, height: barHeight, decoration: BoxDecoration(color: Colors.blue.shade300, borderRadius: BorderRadius.circular(4))),
        const SizedBox(height: 8),
        Text(day, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
      ],
    );
  }

  // --- WIDGET: STAT CARD ---
  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: color.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }

  // --- WIDGET: COIN SUMMARY ---
  Widget _buildWeeklyCoinSummary(String uid) {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(uid).collection('daily_stats').get(),
      builder: (context, snapshot) {
        int weeklyCoins = 0;
        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            var data = doc.data() as Map<String, dynamic>;
            weeklyCoins += (data['coins_earned'] ?? 0) as int;
          }
        }
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(15)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.monetization_on, color: Colors.amber, size: 30),
              const SizedBox(width: 15),
              const Text("Total Coins this Week: ", style: TextStyle(fontWeight: FontWeight.bold)),
              Text("$weeklyCoins", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange)),
            ],
          ),
        );
      },
    );
  }
}