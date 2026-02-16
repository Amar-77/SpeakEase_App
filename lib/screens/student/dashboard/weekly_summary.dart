import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:speakease/screens/student/dashboard/word_practice_screen.dart';

class WeeklySummaryScreen extends StatefulWidget {
  const WeeklySummaryScreen({super.key});

  @override
  State<WeeklySummaryScreen> createState() => _WeeklySummaryScreenState();
}

class _WeeklySummaryScreenState extends State<WeeklySummaryScreen> {
  // 0 = Current Week, 1 = Last Week, etc.
  int _weekOffset = 0;

  void _changeWeek(int delta) {
    setState(() {
      _weekOffset += delta;
      if (_weekOffset < 0) _weekOffset = 0; // Can't go into the future
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;
    final DateTime now = DateTime.now();

    // Calculate the dynamic window based on offset
    // If offset is 0: End = Today, Start = Today - 6
    // If offset is 1: End = Today - 7, Start = Today - 13
    final DateTime endDate = now.subtract(Duration(days: _weekOffset * 7));
    final DateTime startDate = endDate.subtract(const Duration(days: 6));

    // Timestamp for fetching metrics (only needed for the current view)
    final Timestamp threshold = Timestamp.fromDate(startDate);

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
            // --- 1. NAVIGATION HEADER ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Weekly History", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),

                // Date Navigator
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded),
                      onPressed: () => _changeWeek(1), // Go back in time
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "${DateFormat('MMM d').format(startDate)} - ${DateFormat('MMM d').format(endDate)}",
                      style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(Icons.chevron_right_rounded, color: _weekOffset == 0 ? Colors.grey.shade300 : Colors.black),
                      onPressed: _weekOffset == 0 ? null : () => _changeWeek(-1), // Go forward
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 15),

            // 🔥 PASS THE DATE RANGE TO THE CHART
            _buildRollingActivityChart(user.uid, startDate, endDate),

            const SizedBox(height: 30),
            const Divider(),
            const SizedBox(height: 15),

            const Text("Performance Metrics (Selected Week)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),

            // --- 2. METRICS (Refreshes based on selected week) ---
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('submissions')
                  .where('student_id', isEqualTo: user.uid)
                  .where('submitted_at', isGreaterThanOrEqualTo: threshold)
                  .where('submitted_at', isLessThanOrEqualTo: Timestamp.fromDate(endDate.add(const Duration(days: 1)))) // End of the day
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

                var docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(15)),
                    child: const Center(child: Text("No practice sessions during this week.", style: TextStyle(color: Colors.grey))),
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

            // --- 3. WORDS TO REVIEW (Global List, not weekly) ---
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

  // --- 🛠️ UPDATED CHART LOGIC ---
  Widget _buildRollingActivityChart(String uid, DateTime start, DateTime end) {
    // 1. Generate the 7 dates for the CURRENTLY selected week
    List<DateTime> daysToShow = List.generate(7, (i) {
      return start.add(Duration(days: i));
    });

    List<String> dateKeys = daysToShow.map((d) => "${d.year}-${d.month}-${d.day}").toList();

    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('daily_stats')
          .where(FieldPath.documentId, whereIn: dateKeys)
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox(height: 150, child: Center(child: CircularProgressIndicator()));

        Map<String, int> minutesMap = {};
        for (var doc in snapshot.data!.docs) {
          var data = doc.data() as Map<String, dynamic>;
          num rawMinutes = data['minutes_spent'] ?? 0;
          minutesMap[doc.id] = rawMinutes.round();
        }

        return Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(15)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: daysToShow.map((date) {
              String key = "${date.year}-${date.month}-${date.day}";
              int minutes = minutesMap[key] ?? 0;
              return _buildRollingBar(date, minutes);
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildRollingBar(DateTime date, int minutes) {
    double barHeight = (minutes * 3.0).clamp(6.0, 100.0);
    // Only highlight if it's ACTUALLY today (ignore past dates even if they match day number)
    bool isToday = date.year == DateTime.now().year &&
        date.month == DateTime.now().month &&
        date.day == DateTime.now().day;

    return Column(
      children: [
        Text(minutes > 0 ? "$minutes" : "", style: const TextStyle(fontSize: 10, color: Colors.grey)),
        const SizedBox(height: 4),
        Container(
          width: 12, height: barHeight,
          decoration: BoxDecoration(
              color: isToday ? Colors.green : Colors.blue.shade300,
              borderRadius: BorderRadius.circular(4)
          ),
        ),
        const SizedBox(height: 8),
        Text(DateFormat('E').format(date), style: TextStyle(fontSize: 10, fontWeight: isToday ? FontWeight.bold : FontWeight.w500, color: isToday ? Colors.black : Colors.grey)),
        Text(DateFormat('d').format(date), style: TextStyle(fontSize: 10, fontWeight: isToday ? FontWeight.bold : FontWeight.w500, color: isToday ? Colors.black : Colors.grey)),
      ],
    );
  }

  // --- HELPERS (Unchanged) ---
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

  Widget _buildMistakeWordListFromFirestore(String uid) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        var userData = snapshot.data!.data() as Map<String, dynamic>?;
        List<String> firestoreMistakes = List<String>.from(userData?['mistake_words'] ?? []);

        if (firestoreMistakes.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(15)),
            child: const Row(children: [Icon(Icons.check_circle, color: Colors.green), SizedBox(width: 10), Text("You've mastered everything! Great job!")]),
          );
        }

        return GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => WordPracticeScreen(mistakeWords: firestoreMistakes, studentId: uid))),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Colors.orange.shade400, Colors.red.shade400]),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))],
            ),
            child: Row(children: [
              const CircleAvatar(backgroundColor: Colors.white24, radius: 25, child: Icon(Icons.psychology, color: Colors.white, size: 30)),
              const SizedBox(width: 15),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text("Mastery Hub", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                Text("${firestoreMistakes.length} words to review", style: const TextStyle(color: Colors.white70)),
              ])),
              const Icon(Icons.arrow_forward, color: Colors.white),
            ]),
          ),
        );
      },
    );
  }

  Widget _buildWeeklyCoinSummary(String uid) {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(uid).collection('daily_stats').get(),
      builder: (context, snapshot) {
        int weeklyCoins = 0;
        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            weeklyCoins += (doc.data() as Map<String, dynamic>)['coins_earned'] as int? ?? 0;
          }
        }
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(15)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.monetization_on, color: Colors.amber, size: 30),
            const SizedBox(width: 15),
            const Text("Total Coins Earned: ", style: TextStyle(fontWeight: FontWeight.bold)),
            Text("$weeklyCoins", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange)),
          ]),
        );
      },
    );
  }
}