import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:speakease/screens/test_models.dart';
import '../practice/practice_list_screen.dart';
import '../dashboard/student_dashboard_screen.dart';
import 'leaderboard_screen.dart'; // <--- NEW IMPORT

class StudentHome extends StatelessWidget {
  const StudentHome({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;

    return Scaffold(
      appBar: AppBar(
        title: const Text("SpeakEase"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: () async => await FirebaseAuth.instance.signOut(),
          )
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          var data = snapshot.data!.data() as Map<String, dynamic>;

          // --- Fetch Gamification Data ---
          int coins = data['speech_coins'] ?? 0;
          int level = data['level'] ?? 1;
          int currentXp = data['current_xp'] ?? 0;
          int maxXp = data['max_xp'] ?? 1200;
          int streak = data['current_streak'] ?? 0;
          String classId = data['class_id'] ?? 'class_6A'; // Needed for Leaderboard

          double progress = currentXp / maxXp;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text("Welcome back,", style: TextStyle(color: Colors.grey, fontSize: 16)),
                Text(data['name'] ?? 'Student', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),

                const SizedBox(height: 20),

                // --- 1. THE GAMIFICATION CARD ---
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [Colors.blue.shade800, Colors.blue.shade500]),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))],
                  ),
                  child: Column(
                    children: [
                      // Top Row: Level & Streak
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
                                child: Text("$level", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("Current Level", style: TextStyle(color: Colors.white70, fontSize: 12)),
                                  Text("Level $level", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                ],
                              )
                            ],
                          ),
                          // Streak Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(color: Colors.orange.shade800, borderRadius: BorderRadius.circular(20)),
                            child: Row(
                              children: [
                                const Icon(Icons.local_fire_department, color: Colors.orangeAccent, size: 18),
                                const SizedBox(width: 5),
                                Text("$streak Day Streak", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          )
                        ],
                      ),
                      const SizedBox(height: 20),
                      // XP Progress Bar
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("$currentXp / $maxXp XP", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              Text("${(progress * 100).toInt()}%", style: const TextStyle(color: Colors.white70)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: progress,
                              backgroundColor: Colors.black26,
                              valueColor: const AlwaysStoppedAnimation<Color>(Colors.greenAccent),
                              minHeight: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      const Divider(color: Colors.white24),
                      const SizedBox(height: 5),
                      // Wallet
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          const Icon(Icons.monetization_on, color: Colors.amber, size: 20),
                          const SizedBox(width: 8),
                          Text("Wallet: $coins Coins", style: const TextStyle(color: Colors.white, fontSize: 16)),
                        ],
                      )
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // --- 2. ACTION GRID ---
                // Row 1: Analytics & Practice
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentDashboardScreen()));
                        },
                        child: Container(
                          height: 120,
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(color: Colors.deepPurple.shade50, borderRadius: BorderRadius.circular(20)),
                          child: const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.bar_chart, size: 40, color: Colors.deepPurple),
                              Spacer(),
                              Text("View\nAnalytics", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.deepPurple)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          //Navigator.push(context, MaterialPageRoute(builder: (_) => TestModelScreen()));
                          Navigator.push(context, MaterialPageRoute(builder: (_) => PracticeSessionList(classId: classId)));
                        },
                        child: Container(
                          height: 120,
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(20)),
                          child: const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.mic, size: 40, color: Colors.teal),
                              Spacer(),
                              Text("Start\nPractice", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.teal)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 15),

                // --- NEW BUTTON: LEADERBOARD ---
                // I added this as a full-width card to make it stand out
                InkWell(
                  onTap: () {
                    // Navigate to Leaderboard, passing the classId
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => LeaderboardScreen(classId: classId)
                        )
                    );
                  },
                  child: Container(
                    height: 100,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF9C4), // Light Yellow (Gold-ish)
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.amber.shade200, width: 1),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.emoji_events, size: 30, color: Colors.amber),
                        ),
                        const SizedBox(width: 20),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text("Class Leaderboard", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87)),
                            Text("See who is top of the class!", style: TextStyle(color: Colors.black54, fontSize: 14)),
                          ],
                        ),
                        const Spacer(),
                        const Icon(Icons.arrow_forward_ios, color: Colors.black26, size: 18),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 30), // Bottom padding
              ],
            ),
          );
        },
      ),
    );
  }
}