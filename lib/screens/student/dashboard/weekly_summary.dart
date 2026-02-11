import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'word_practice_screen.dart';

class WeeklySummaryScreen extends StatelessWidget {
  const WeeklySummaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;
    final DateTime now = DateTime.now();
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
            const Text("Practice Consistency", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            _buildActivityChart(user.uid),

            const SizedBox(height: 30),
            const Divider(),
            const SizedBox(height: 15),

            const Text("Performance Metrics", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),

            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('submissions')
                  .where('student_id', isEqualTo: user.uid)
                  .where('submitted_at', isGreaterThanOrEqualTo: threshold)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

                var docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: Text("No practice sessions found for this week.", style: TextStyle(color: Colors.grey))),
                  );
                }

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

            // --- UPDATED SECTION 3: WORDS TO REVIEW (FETCHED FROM FIRESTORE ONLY) ---
            const Text("Words to Review", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            _buildMistakeWordListFromFirestore(user.uid),

            const SizedBox(height: 30),

            _buildWeeklyCoinSummary(user.uid),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // --- UPDATED WIDGET: USES FIRESTORE 'mistake_words' FIELD ---
  Widget _buildMistakeWordListFromFirestore(String uid) {
    return StreamBuilder<DocumentSnapshot>(
      // 1. Listen directly to the user's document for the mistake_words field
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Text("Error loading hub.");
        if (!snapshot.hasData) return const SizedBox();

        var userData = snapshot.data!.data() as Map<String, dynamic>?;
        // 2. Fetch the persistent list from Firestore
        List<String> firestoreMistakes = List<String>.from(userData?['mistake_words'] ?? []);

        // 3. Show a success message if the list is empty
        if (firestoreMistakes.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(15)),
            child: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 10),
                Text("You've mastered everything! Great job!"),
              ],
            ),
          );
        }

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => WordPracticeScreen(
                  // 4. Pass the Firestore words to the Hub
                  mistakeWords: firestoreMistakes, 
                  studentId: uid,
                ),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Colors.orange.shade400, Colors.red.shade400]),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))],
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Colors.white24,
                  radius: 25,
                  child: Icon(Icons.psychology, color: Colors.white, size: 30),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Mastery Hub", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      Text("${firestoreMistakes.length} words need your attention", style: const TextStyle(color: Colors.white70)),
                    ],
                  ),
                ),
                const Icon(Icons.play_circle_fill, color: Colors.white, size: 40),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- ALL OTHER HELPER WIDGETS (UNCHANGED) ---
  Widget _buildActivityChart(String uid) {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(uid).collection('daily_stats').orderBy('date', descending: true).limit(7).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()));
        var docs = snapshot.data!.docs;
        Map<String, int> weekData = {"Mon": 0, "Tue": 0, "Wed": 0, "Thu": 0, "Fri": 0, "Sat": 0, "Sun": 0};
        for (var doc in docs) {
          var d = doc.data() as Map<String, dynamic>;
          String dateStr = d['date'] ?? "";
          if (dateStr.isNotEmpty) {
            try {
              DateTime dt = DateFormat("yyyy-M-d").parse(dateStr);
              String dayName = ["", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"][dt.weekday];
              weekData[dayName] = d['minutes_spent'] ?? 0;
            } catch (e) {
              debugPrint("Error parsing date: $dateStr - $e");
            }
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