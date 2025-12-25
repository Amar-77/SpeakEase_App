import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart'; // Add this to pubspec.yaml if needed, or use basic logic

class StudentDashboardScreen extends StatelessWidget {
  const StudentDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;

    return Scaffold(
      appBar: AppBar(title: const Text("My Activity"), backgroundColor: Colors.white, foregroundColor: Colors.black, elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Weekly Report", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const Text("Last 7 Days Activity", style: TextStyle(color: Colors.grey)),

            const SizedBox(height: 20),

            // --- 1. THE BAR CHART (Now with Real Data) ---
            FutureBuilder<Map<String, int>>(
              future: _fetchWeeklyStats(user.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
                }

                if (snapshot.hasError) {
                  return const SizedBox(height: 200, child: Center(child: Text("Error loading chart")));
                }

                // Get the processed data
                Map<String, int> weeklyData = snapshot.data ?? {};
                int totalMinutes = weeklyData.values.fold(0, (sum, val) => sum + val);
                int maxVal = 60; // Max scale (can be dynamic, but 60 is good for minutes)

                // Sort keys to ensure Mon -> Sun order isn't messed up visually
                // (Though our helper builds specific days, the map is just for lookup)

                return Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, spreadRadius: 5)],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _buildBar("Mon", weeklyData['Mon'] ?? 0, maxVal, Colors.blue),
                          _buildBar("Tue", weeklyData['Tue'] ?? 0, maxVal, Colors.blue),
                          _buildBar("Wed", weeklyData['Wed'] ?? 0, maxVal, Colors.blue),
                          _buildBar("Thu", weeklyData['Thu'] ?? 0, maxVal, Colors.blue),
                          _buildBar("Fri", weeklyData['Fri'] ?? 0, maxVal, Colors.blue),
                          _buildBar("Sat", weeklyData['Sat'] ?? 0, maxVal, Colors.orange), // Weekends
                          _buildBar("Sun", weeklyData['Sun'] ?? 0, maxVal, Colors.orange),
                        ],
                      ),
                      const SizedBox(height: 15),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Total Practice: $totalMinutes mins", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                          const Icon(Icons.access_time, color: Colors.blueGrey, size: 18),
                        ],
                      )
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 30),

            // --- 2. USAGE BREAKDOWN (Still simulated for now) ---
            const Text("Focus Areas", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),

            // Note: We can connect these to DB later if we track categories separately
            _buildStatRow("Stories", 45, Colors.purple),
            _buildStatRow("Tongue Twisters", 30, Colors.pink),
            _buildStatRow("Vowel Practice", 25, Colors.teal),
          ],
        ),
      ),
    );
  }

  // --- LOGIC: Fetch Last 7 Days from Firestore ---
  Future<Map<String, int>> _fetchWeeklyStats(String uid) async {
    DateTime now = DateTime.now();
    Map<String, int> statsMap = {
      "Mon": 0, "Tue": 0, "Wed": 0, "Thu": 0, "Fri": 0, "Sat": 0, "Sun": 0
    };

    // Calculate the start of the current week (Monday)
    // This logic gets the current week's data.
    // If you want a "rolling window" (last 7 days regardless of week), logic changes slightly.
    // Let's stick to "Current Week" for simplicity.

    // Simple approach: Get ALL docs from daily_stats and filter locally
    // (Since a user won't have thousands of docs yet, this is safe and fast)
    QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('daily_stats')
        .limit(30) // Just get recent month
        .get();

    for (var doc in snapshot.docs) {
      var data = doc.data() as Map<String, dynamic>;
      String dateStr = data['date']; // "2025-7-24"
      int minutes = data['minutes_spent'] ?? 0;

      // Parse date
      try {
        List<String> parts = dateStr.split('-');
        DateTime date = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));

        // Get Day Name (Mon, Tue...)
        // We can check if this date is within the last 7 days of "now"
        if (now.difference(date).inDays < 7) {
          String dayName = _getDayName(date.weekday); // 1 = Mon
          statsMap[dayName] = (statsMap[dayName] ?? 0) + minutes;
        }
      } catch (e) {
        print("Date parse error: $e");
      }
    }
    return statsMap;
  }

  String _getDayName(int weekday) {
    switch (weekday) {
      case 1: return "Mon";
      case 2: return "Tue";
      case 3: return "Wed";
      case 4: return "Thu";
      case 5: return "Fri";
      case 6: return "Sat";
      case 7: return "Sun";
      default: return "";
    }
  }

  // Helper to build a single Bar
  Widget _buildBar(String day, int minutes, int max, Color color) {
    double heightFactor = minutes / max;
    if (heightFactor > 1.0) heightFactor = 1.0;

    // Dynamic color: Make today's bar stand out
    // (Optional enhancement, keeping simple color for now)

    return Column(
      children: [
        Text("$minutes", style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
        const SizedBox(height: 5),
        Container(
          width: 12,
          height: 150 * heightFactor == 0 ? 2 : 150 * heightFactor, // Min height 2 so it shows 0
          decoration: BoxDecoration(
            color: color.withOpacity(0.8),
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(height: 8),
        Text(day, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  // Helper for Focus Areas
  Widget _buildStatRow(String label, int percentage, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text("$percentage%", style: TextStyle(color: color, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: percentage / 100,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }
}