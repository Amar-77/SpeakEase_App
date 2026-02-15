import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
// REPLACE with your actual path
import 'package:speakease/screens/student/dashboard/weekly_summary.dart';

import '../chat/speaky_screen.dart';

class StudentDashboardScreen extends StatelessWidget {
  const StudentDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;
    String displayName = user.displayName?.split(' ')[0] ?? "Student";

    return Scaffold(
      backgroundColor: Colors.grey[50], // Light background for better contrast
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Dashboard", style: TextStyle(color: Colors.black, fontSize: 20)),
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
            // --- 1. NEW: SPEAKY AI CALL TO ACTION ---
            _buildSpeakyCard(context),
            const SizedBox(height: 25),

            // --- 2. WEEKLY ACTIVITY CHART ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text("Weekly Activity", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text("Last 7 Days", style: TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 15),

            FutureBuilder<Map<String, int>>(
              future: _fetchWeeklyStats(user.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
                }
                if (snapshot.hasError) {
                  return _buildErrorCard("Could not load stats");
                }

                Map<String, int> weeklyData = snapshot.data ?? {};
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
                              const Text("Total practice this week", style: TextStyle(color: Colors.grey, fontSize: 12)),
                            ],
                          )
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 10),

                      // The Bar Chart
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _buildBar("Mon", weeklyData['Mon'] ?? 0, 60, Colors.blue),
                          _buildBar("Tue", weeklyData['Tue'] ?? 0, 60, Colors.blue),
                          _buildBar("Wed", weeklyData['Wed'] ?? 0, 60, Colors.blue),
                          _buildBar("Thu", weeklyData['Thu'] ?? 0, 60, Colors.blue),
                          _buildBar("Fri", weeklyData['Fri'] ?? 0, 60, Colors.blue),
                          _buildBar("Sat", weeklyData['Sat'] ?? 0, 60, Colors.orange),
                          _buildBar("Sun", weeklyData['Sun'] ?? 0, 60, Colors.orange),
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

            // --- 3. FOCUS AREAS (Simulated) ---
            const Text("Your Focus Areas", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            _buildStatRow("Fluency", 75, Colors.purple),
            _buildStatRow("Pronunciation", 60, Colors.pink),
            _buildStatRow("Vocabulary", 45, Colors.teal),
          ],
        ),
      ),
    );
  }

  // --- WIDGETS ---

  Widget _buildSpeakyCard(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SpeakyChatScreen()),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [Colors.blue.shade800, Colors.blue.shade500]),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
              child: const Icon(Icons.mic, color: Colors.white, size: 30),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
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
    double heightFactor = minutes / max;
    if (heightFactor > 1.0) heightFactor = 1.0;
    // Ensure at least a tiny bar is visible if 0
    double displayHeight = 100 * heightFactor;
    if (displayHeight < 4) displayHeight = 4;

    bool isToday = DateFormat('E').format(DateTime.now()) == day;

    return Column(
      children: [
        Container(
          width: 12,
          height: displayHeight,
          decoration: BoxDecoration(
            color: isToday ? Colors.green : color.withOpacity(0.7),
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(height: 8),
        Text(
            day,
            style: TextStyle(
                fontSize: 12,
                fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                color: isToday ? Colors.green : Colors.grey
            )
        ),
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
      height: 150,
      width: double.infinity,
      decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(20)),
      child: Center(child: Text(msg, style: TextStyle(color: Colors.red[800]))),
    );
  }

  // --- LOGIC ---
  Future<Map<String, int>> _fetchWeeklyStats(String uid) async {
    DateTime now = DateTime.now();
    Map<String, int> statsMap = {
      "Mon": 0, "Tue": 0, "Wed": 0, "Thu": 0, "Fri": 0, "Sat": 0, "Sun": 0
    };

    try {
      // Fetch stats
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('daily_stats')
          .limit(10) // Small limit for dashboard
          .get();

      for (var doc in snapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;
        String dateStr = data['date'];
        int minutes = data['minutes_spent'] ?? 0;

        try {
          // Robust Parsing: Handles "2025-7-5" and "2025-07-05"
          List<String> parts = dateStr.split('-');
          if (parts.length == 3) {
            DateTime date = DateTime(
                int.parse(parts[0]),
                int.parse(parts[1]),
                int.parse(parts[2])
            );

            // Only add if within last 7 days
            if (now.difference(date).inDays < 7) {
              String dayName = DateFormat('E').format(date); // "Mon", "Tue"
              statsMap[dayName] = (statsMap[dayName] ?? 0) + minutes;
            }
          }
        } catch (e) {
          print("Date parse error for $dateStr: $e");
        }
      }
    } catch (e) {
      print("Firestore error: $e");
    }
    return statsMap;
  }
}