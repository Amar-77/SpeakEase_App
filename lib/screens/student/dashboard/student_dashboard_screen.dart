import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:speakease/screens/student/dashboard/weekly_summary.dart';
import '../chat/speaky_screen.dart';

class StudentDashboardScreen extends StatelessWidget {
  const StudentDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;
    String displayName = user.displayName?.split(' ')[0] ?? "Student";

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Dashboard", style: TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold)),
            Text("Welcome back, $displayName 👋", style: const TextStyle(color: Colors.grey, fontSize: 14)),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- 1. SPEAKY AI CARD ---
            _buildSpeakyCard(context),
            const SizedBox(height: 25),

            // --- 2. WEEKLY ACTIVITY CHART (Updated UI) ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Weekly Activity", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                // Dynamic Date Range Display (e.g., "Feb 12 - Feb 18")
                Text("This Week", style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 15),

            FutureBuilder<Map<String, int>>(
              future: _fetchCurrentWeekStats(user.uid), // 👈 NEW FUNCTION
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
                }
                if (snapshot.hasError) {
                  return _buildErrorCard("Could not load stats");
                }

                Map<String, int> weeklyData = snapshot.data ?? {};
                // Calculate total minutes for THIS week only
                int totalMinutes = weeklyData.values.fold(0, (sum, val) => sum + val);

                return Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: Column(
                    children: [
                      // Total Counter
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.timer, color: Colors.blue),
                          ),
                          const SizedBox(width: 15),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("$totalMinutes mins", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                              const Text("Practice this week", style: TextStyle(color: Colors.grey, fontSize: 12)),
                            ],
                          )
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 10),

                      // The Bar Chart (Mon - Sun)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _buildBar("Mon", weeklyData['Mon'] ?? 0, 45, Colors.blue),
                          _buildBar("Tue", weeklyData['Tue'] ?? 0, 45, Colors.blue),
                          _buildBar("Wed", weeklyData['Wed'] ?? 0, 45, Colors.blue),
                          _buildBar("Thu", weeklyData['Thu'] ?? 0, 45, Colors.blue),
                          _buildBar("Fri", weeklyData['Fri'] ?? 0, 45, Colors.blue),
                          _buildBar("Sat", weeklyData['Sat'] ?? 0, 45, Colors.orange),
                          _buildBar("Sun", weeklyData['Sun'] ?? 0, 45, Colors.orange),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 20),

            // Weekly Summary Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const WeeklySummaryScreen()));
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("View Detailed History", style: TextStyle(color: Colors.black)),
              ),
            ),

            const SizedBox(height: 30),

            // --- 3. FOCUS AREAS ---
            const Text("Your Focus Areas", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            _buildStatRow("Fluency", 75, Colors.purple),
            _buildStatRow("Pronunciation", 60, Colors.pink),
            _buildStatRow("Vocabulary", 45, Colors.teal),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // --- 🛠️ FIXED: Safe Double-to-Int Conversion ---
  Future<Map<String, int>> _fetchCurrentWeekStats(String uid) async {
    DateTime now = DateTime.now();

    // 1. Find the Monday of the current week
    DateTime startOfWeek = now.subtract(Duration(days: now.weekday - 1));

    // 2. Generate keys (Mon-Sun)
    List<String> weekDates = [];
    for (int i = 0; i < 7; i++) {
      DateTime day = startOfWeek.add(Duration(days: i));
      weekDates.add("${day.year}-${day.month}-${day.day}");
    }

    // 3. Initialize all to 0
    Map<String, int> statsMap = {
      "Mon": 0, "Tue": 0, "Wed": 0, "Thu": 0, "Fri": 0, "Sat": 0, "Sun": 0
    };

    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('daily_stats')
          .where(FieldPath.documentId, whereIn: weekDates)
          .get();

      for (var doc in snapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;
        String dateStr = data['date'];

        // ⚠️ THE FIX: Use 'num' instead of 'int' to accept Doubles (5.5)
        num rawMinutes = data['minutes_spent'] ?? 0;
        int minutes = rawMinutes.round(); // Safely convert to Int

        // Parse date to get the day name
        List<String> parts = dateStr.split('-');
        DateTime date = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
        String dayName = DateFormat('E').format(date);

        statsMap[dayName] = minutes;
      }
    } catch (e) {
      debugPrint("Stats Error: $e");
    }

    return statsMap;
  }

  // Helper to show the date range string (e.g., "Feb 10 - Feb 16")
  String _getWeekRangeString() {
    DateTime now = DateTime.now();
    DateTime startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    DateTime endOfWeek = startOfWeek.add(const Duration(days: 6));
    return "${DateFormat('MMM d').format(startOfWeek)} - ${DateFormat('MMM d').format(endOfWeek)}";
  }

  // --- WIDGET HELPERS (Unchanged mostly) ---

  Widget _buildSpeakyCard(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SpeakyChatScreen())),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [Colors.blue.shade800, Colors.blue.shade500]),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
              child: const Icon(Icons.mic, color: Colors.white, size: 30),
            ),
            const SizedBox(width: 15),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Talk with Speaky AI", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  SizedBox(height: 5),
                  Text("Practice conversation & get instant feedback.", style: TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildBar(String day, int minutes, int max, Color color) {
    // Cap at 1.0 (100%) but show full bar if over
    double heightFactor = (minutes / max).clamp(0.0, 1.0);
    double displayHeight = 100 * heightFactor;

    // Min height 4 so 0 isn't invisible
    if (displayHeight < 4) displayHeight = 4;

    bool isToday = DateFormat('E').format(DateTime.now()) == day;

    return Column(
      children: [
        // Tooltip showing exact minutes
        Text(
            minutes > 0 ? "$minutes" : "",
            style: TextStyle(fontSize: 10, color: Colors.grey[600], fontWeight: FontWeight.bold)
        ),
        const SizedBox(height: 4),
        Container(
          width: 12,
          height: displayHeight,
          decoration: BoxDecoration(
            color: isToday ? Colors.green : color.withOpacity(0.7),
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(height: 8),
        Text(day, style: TextStyle(fontSize: 12, fontWeight: isToday ? FontWeight.bold : FontWeight.normal, color: isToday ? Colors.green : Colors.grey)),
      ],
    );
  }

  Widget _buildStatRow(String label, int percentage, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text("$percentage%", style: TextStyle(color: color, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: percentage / 100,
              backgroundColor: color.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(String msg) {
    return Container(
      height: 150, width: double.infinity,
      decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(20)),
      child: Center(child: Text(msg, style: TextStyle(color: Colors.red[800]))),
    );
  }
}