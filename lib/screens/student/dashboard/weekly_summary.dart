import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:speakease/screens/student/dashboard/word_practice_screen.dart';

/// This screen is no longer opened via Navigator from the dashboard.
/// The dashboard now handles inline weekly view via _weekOffset.
/// WeeklySummaryScreen is kept for deep-linking / standalone access.

class WeeklySummaryScreen extends StatefulWidget {
  const WeeklySummaryScreen({super.key});

  @override
  State<WeeklySummaryScreen> createState() => _WeeklySummaryScreenState();
}

class _WeeklySummaryScreenState extends State<WeeklySummaryScreen> {
  int _weekOffset = 0;

  void _changeWeek(int delta) {
    setState(() {
      _weekOffset += delta;
      if (_weekOffset < 0) _weekOffset = 0;
    });
  }

  DateTime get _endDate =>
      DateTime.now().subtract(Duration(days: _weekOffset * 7));
  DateTime get _startDate => _endDate.subtract(const Duration(days: 6));

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;
    final Timestamp startTs = Timestamp.fromDate(_startDate);
    final Timestamp endTs =
    Timestamp.fromDate(_endDate.add(const Duration(days: 1)));

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        title: const Text("Weekly Reflection",
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
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
            // ── Week Navigation Header ──
            _buildWeekNav(),
            const SizedBox(height: 16),

            // ── Rolling Activity Chart ──
            _buildRollingActivityChart(user.uid),
            const SizedBox(height: 24),

            // ── Performance Metrics ──
            const Text("Performance Metrics",
                style:
                TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
              "${DateFormat('MMM d').format(_startDate)} – ${DateFormat('MMM d').format(_endDate)}",
              style:
              const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 14),
            _buildMetricsGrid(user.uid, startTs, endTs),

            const SizedBox(height: 30),

            // ── Words to Review ──
            const Text("Words to Review",
                style:
                TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildMistakeWordList(user.uid),

            const SizedBox(height: 30),

            // ── Coin Summary ──
            _buildWeeklyCoinSummary(user.uid),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // ─── WEEK NAV ─────────────────────────────────────────────────────────────────

  Widget _buildWeekNav() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text("Weekly History",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2))
            ],
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => _changeWeek(1),
                child:
                const Icon(Icons.chevron_left_rounded, color: Colors.black),
              ),
              const SizedBox(width: 6),
              Text(
                "${DateFormat('MMM d').format(_startDate)} - ${DateFormat('MMM d').format(_endDate)}",
                style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: _weekOffset == 0 ? null : () => _changeWeek(-1),
                child: Icon(Icons.chevron_right_rounded,
                    color: _weekOffset == 0
                        ? Colors.grey.shade300
                        : Colors.black),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── CHART ───────────────────────────────────────────────────────────────────

  Widget _buildRollingActivityChart(String uid) {
    List<DateTime> days =
    List.generate(7, (i) => _startDate.add(Duration(days: i)));
    List<String> dateKeys =
    days.map((d) => "${d.year}-${d.month}-${d.day}").toList();

    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('daily_stats')
          .where(FieldPath.documentId, whereIn: dateKeys)
          .get(),
      builder: (context, snapshot) {
        Map<String, int> minutesMap = {};
        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            var data = doc.data() as Map<String, dynamic>;
            num raw = data['minutes_spent'] ?? 0;
            minutesMap[doc.id] = raw.round();
          }
        }

        int maxVal = minutesMap.values.fold(1, (m, v) => v > m ? v : m);

        return Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4))
            ],
          ),
          child: snapshot.connectionState == ConnectionState.waiting
              ? const SizedBox(
              height: 100,
              child: Center(child: CircularProgressIndicator()))
              : SizedBox(
            height: 110,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: days.map((date) {
                String key = "${date.year}-${date.month}-${date.day}";
                int minutes = minutesMap[key] ?? 0;
                double frac =
                (minutes / maxVal).clamp(0.04, 1.0);
                bool isToday = date.year == DateTime.now().year &&
                    date.month == DateTime.now().month &&
                    date.day == DateTime.now().day;
                bool isWeekend =
                    date.weekday == 6 || date.weekday == 7;

                Color barColor = isToday
                    ? const Color(0xFF34C759)
                    : isWeekend
                    ? const Color(0xFFFF6B6B)
                    : const Color(0xFF7B72F0);

                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (minutes > 0)
                      Text("$minutes",
                          style: const TextStyle(
                              fontSize: 9,
                              color: Colors.grey,
                              fontWeight: FontWeight.w600)),
                    const SizedBox(height: 3),
                    Container(
                      width: 28,
                      height: 80 * frac,
                      decoration: BoxDecoration(
                        color: barColor.withOpacity(isToday ? 1 : 0.8),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(DateFormat('E').format(date),
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: isToday
                                ? FontWeight.bold
                                : FontWeight.w500,
                            color: isToday
                                ? Colors.black
                                : Colors.grey.shade500)),
                    Text(DateFormat('d').format(date),
                        style: TextStyle(
                            fontSize: 10,
                            color: isToday
                                ? Colors.black
                                : Colors.grey.shade400)),
                  ],
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  // ─── METRICS GRID ────────────────────────────────────────────────────────────

  Widget _buildMetricsGrid(
      String uid, Timestamp startTs, Timestamp endTs) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('submissions')
          .where('student_id', isEqualTo: uid)
          .where('submitted_at', isGreaterThanOrEqualTo: startTs)
          .where('submitted_at', isLessThanOrEqualTo: endTs)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildInfoBox(
              "Error loading metrics", Colors.red.shade50, Colors.red);
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        var docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return _buildInfoBox("No practice sessions this week.",
              Colors.grey.shade50, Colors.grey);
        }

        double acc = 0, flu = 0, clar = 0, pron = 0, wpm = 0;
        for (var doc in docs) {
          var d = doc.data() as Map<String, dynamic>;
          acc += (d['accuracy_score'] ?? 0).toDouble();
          flu += (d['fluency_score'] ?? 0).toDouble();
          clar += (d['clarity_score'] ?? 0).toDouble();
          pron += (d['pronunciation_score'] ?? 0).toDouble();
          wpm += (d['wpm'] ?? 0).toDouble();
        }
        int c = docs.length;

        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: 1.15,
          children: [
            _buildMetricCard("Avg Accuracy",
                "${(acc / c).toStringAsFixed(1)}%", Icons.verified, Colors.green),
            _buildMetricCard("Avg Fluency", (flu / c).toStringAsFixed(1),
                Icons.waves, Colors.blue),
            _buildMetricCard("Pronunciation",
                (pron / c).toStringAsFixed(1), Icons.record_voice_over, Colors.purple),
            _buildMetricCard("Avg Clarity",
                "${(clar / c).toStringAsFixed(1)}%", Icons.hearing, Colors.orange),
            _buildMetricCard("Avg WPM", (wpm / c).toStringAsFixed(0),
                Icons.speed, Colors.red),
          ],
        );
      },
    );
  }

  Widget _buildMetricCard(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: color.withOpacity(0.12),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 8),
          Text(value,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold)),
          Text(label,
              textAlign: TextAlign.center,
              style:
              const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }

  // ─── MISTAKE WORDS ───────────────────────────────────────────────────────────

  Widget _buildMistakeWordList(String uid) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        var userData =
        snapshot.data!.data() as Map<String, dynamic>?;
        List<String> words =
        List<String>.from(userData?['mistake_words'] ?? []);

        if (words.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(16)),
            child: const Row(children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 12),
              Text("You've mastered everything! Great job! 🎉"),
            ]),
          );
        }

        return GestureDetector(
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => WordPracticeScreen(
                      mistakeWords: words, studentId: uid))),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [Colors.orange.shade400, Colors.red.shade400]),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                    color: Colors.red.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 5))
              ],
            ),
            child: Row(children: [
              CircleAvatar(
                  backgroundColor: Colors.white24,
                  radius: 26,
                  child: const Icon(Icons.psychology,
                      color: Colors.white, size: 28)),
              const SizedBox(width: 14),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Mastery Hub",
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold)),
                        Text("${words.length} words to review",
                            style: const TextStyle(
                                color: Colors.white70)),
                      ])),
              const Icon(Icons.arrow_forward, color: Colors.white),
            ]),
          ),
        );
      },
    );
  }

  // ─── COIN SUMMARY ────────────────────────────────────────────────────────────

  Widget _buildWeeklyCoinSummary(String uid) {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('daily_stats')
          .get(),
      builder: (context, snapshot) {
        int coins = 0;
        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            coins +=
                (doc.data() as Map<String, dynamic>)['coins_earned']
                as int? ??
                    0;
          }
        }
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.amber.shade200)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.monetization_on,
                color: Colors.amber, size: 28),
            const SizedBox(width: 12),
            const Text("Total Coins Earned: ",
                style: TextStyle(fontWeight: FontWeight.bold)),
            Text("$coins",
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange)),
          ]),
        );
      },
    );
  }

  // ─── HELPERS ─────────────────────────────────────────────────────────────────

  Widget _buildInfoBox(String msg, Color bg, Color textColor) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration:
      BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
      child: Center(
          child: Text(msg,
              style: TextStyle(color: textColor, fontWeight: FontWeight.w500))),
    );
  }
}