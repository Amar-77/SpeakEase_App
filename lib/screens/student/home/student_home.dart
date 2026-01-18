import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../practice/practice_list_screen.dart';
import '../dashboard/student_dashboard_screen.dart';
import 'leaderboard_screen.dart';

class StudentHome extends StatelessWidget {
  const StudentHome({super.key});

  @override
  Widget build(BuildContext context) {
    // For responsive sizing
    final size = MediaQuery.of(context).size;
    final user = FirebaseAuth.instance.currentUser!;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            backgroundColor: Colors.grey,
            body: Center(child: CircularProgressIndicator()),
          );
        }

        var data = snapshot.data!.data() as Map<String, dynamic>;

        // Fetch user data
        String userName = data['name'] ?? 'User';
        int coins = data['speech_coins'] ?? 872;
        int level = data['level'] ?? 7;
        int currentXp = data['current_xp'] ?? 980;
        int maxXp = data['max_xp'] ?? 1200;
        int streak = data['current_streak'] ?? 3;
        String classId = data['class_id'] ?? 'class_6A';

        return Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: Stack(
              children: [
                // Main Scrollable Content
                SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- TOP BAR (Updated) ---
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Left Side: Menu & Notification
                          Row(
                            children: [
                              const Icon(Icons.menu_rounded, size: 30, color: Colors.black87),
                              const SizedBox(width: 15),
                              const Icon(Icons.notifications_none_rounded, size: 30, color: Colors.black87),
                            ],
                          ),

                          // Right Side: Coins & Avatar
                          Row(
                            children: [
                              // 1. Speech Coin Image (From Assets)
                              Image.asset(
                                'assets/images/speech_coin.png', // Ensure this matches your file name
                                width: 30, // Adjust size to match reference
                                height: 30,
                                fit: BoxFit.contain,
                              ),
                              const SizedBox(width: 8),

                              // 2. Coin Count Text
                              Text(
                                coins.toString(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600, // Slightly less bold than "ExtraBold" for a cleaner look
                                  fontSize: 18,
                                  color: Colors.black87,
                                ),
                              ),

                              const SizedBox(width: 20), // Space between text and avatar

                              // 3. User Avatar
                              CircleAvatar(
                                radius: 22,
                                backgroundImage: const AssetImage('assets/images/user_avatar.jpg'),
                                backgroundColor: Colors.grey.shade200,
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 25),

                      // --- HERO SECTION ---
                      Container(
                        width: double.infinity,
                        height: size.height * 0.38,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.blue.shade50, Colors.purple.shade50],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(32),
                        ),
                        child: Stack(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'WELCOME,',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    userName.toUpperCase() + '!',
                                    style: const TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.black,
                                      height: 1.0,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    '11th December 2025',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade500,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 15),
                                  // Streak Badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)
                                        ]
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.local_fire_department, color: Colors.orange, size: 18),
                                        const SizedBox(width: 4),
                                        Text(
                                          '$streak Day Streak',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  const Spacer(),

                                  // Level Bar
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'lvl $level',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Expanded(
                                            flex: 3,
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(10),
                                              child: LinearProgressIndicator(
                                                value: currentXp / maxXp,
                                                backgroundColor: Colors.grey.shade300,
                                                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4CAF50)),
                                                minHeight: 12,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 80),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        '$currentXp/$maxXp',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade500,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  )
                                ],
                              ),
                            ),
                            // Character
                            Positioned(
                              right: -90,
                              bottom: 0,
                              child: Image.asset(
                                'assets/images/home_kid_with_mic.png',
                                height: size.height * 0.32,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 30),

                      const Text(
                        'Category',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 15),

                      // Grid Layout
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left Column (Big Card)
                          Expanded(
                            flex: 1,
                            child: GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PracticeSessionList(classId: classId),
                                  ),
                                );
                              },
                              child: Container(
                                height: 240,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF3E5F5),
                                  borderRadius: BorderRadius.circular(28),
                                ),
                                child: Stack(
                                  children: [
                                    Positioned(
                                      top: 15,
                                      right: 15,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFD54F),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: const Text(
                                          'NEW',
                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      top: 40,
                                      left: 0,
                                      right: 0,
                                      child: Center(
                                        child: Image.asset(
                                          'assets/images/mic_floating.png',
                                          height: 120,
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                    ),
                                    const Positioned(
                                      bottom: 20,
                                      left: 20,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('New', style: TextStyle(fontSize: 18, height: 1.1, fontWeight: FontWeight.w800)),
                                          Text('Practice', style: TextStyle(fontSize: 18, height: 1.1, fontWeight: FontWeight.w800)),
                                          Text('Sessions', style: TextStyle(fontSize: 18, height: 1.1, fontWeight: FontWeight.w800)),
                                        ],
                                      ),
                                    )
                                  ],
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(width: 16),

                          // Right Column
                          Expanded(
                            flex: 1,
                            child: Column(
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => LeaderboardScreen(classId: classId),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    height: 112,
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFF8E1),
                                      borderRadius: BorderRadius.circular(24),
                                    ),
                                    child: Row(
                                      children: [
                                        Image.asset('assets/images/assigned_test.png', height: 50),
                                        const SizedBox(width: 12),
                                        const Expanded(
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text('Home', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, height: 1.0)),
                                              Text('works', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, height: 1.0)),
                                              Text('Pending', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, height: 1.0)),
                                            ],
                                          ),
                                        )
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const StudentDashboardScreen(),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    height: 112,
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE1F5FE),
                                      borderRadius: BorderRadius.circular(24),
                                    ),
                                    child: Row(
                                      children: [
                                        const Expanded(
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text('Detailed', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, height: 1.1)),
                                              Text('Analysis', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, height: 1.1)),
                                            ],
                                          ),
                                        ),
                                        Image.asset('assets/images/detailed_analysis.png', height: 50),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),

                // Floating Bottom Nav
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 30, left: 40, right: 40),
                    height: 70,
                    decoration: BoxDecoration(
                      color: const Color(0xFF222222),
                      borderRadius: BorderRadius.circular(35),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 10),
                        )
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.home_rounded, color: Colors.black),
                        ),
                        IconButton(
                          icon: const Icon(Icons.emoji_events_outlined, color: Colors.white54, size: 28),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => LeaderboardScreen(classId: classId),
                              ),
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.bar_chart_rounded, color: Colors.white54, size: 28),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const StudentDashboardScreen(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}