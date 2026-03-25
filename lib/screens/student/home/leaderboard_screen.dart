import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:speakease/screens/student/home/widgets/student_app_bar.dart';

class LeaderboardScreen extends StatelessWidget {
  final String classId;

  const LeaderboardScreen({super.key, required this.classId});

  @override
  Widget build(BuildContext context) {
    final currentUserUid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFFDF7E4), // Cream background for system status bar
      body: Column(
        children: [
          // 1. 🔥 SHARED APP BAR
          const SafeArea(
            bottom: false,
            child: StudentAppBar(),
          ),

          // 2. Main Content (Scrollable)
          Expanded(
            child: Stack(
              children: [
                // 🔥 THE UI FIX: A split background hidden behind the scroll view.
                // When you pull down, you see the cream. When you pull up, you see white.
                Column(
                  children: [
                    Container(height: 200, color: const Color(0xFFFDF7E4)), // Top Cream Buffer
                    Expanded(child: Container(color: Colors.white)),        // Bottom White Buffer
                  ],
                ),

                // 3. The actual foreground content
                StreamBuilder<QuerySnapshot>(
                  // Fetch ALL students in this class
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .where('class_id', isEqualTo: classId)
                      .where('role', isEqualTo: 'student')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(child: Text("Error: ${snapshot.error}"));
                    }
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final docs = snapshot.data!.docs;
                    if (docs.isEmpty) {
                      return const Center(
                          child: Text("No students found in this class yet!"));
                    }

                    // Sort by coins descending
                    docs.sort((a, b) {
                      final dataA = a.data() as Map<String, dynamic>;
                      final dataB = b.data() as Map<String, dynamic>;

                      int coinsA = dataA['speech_coins'] ?? 0;
                      int coinsB = dataB['speech_coins'] ?? 0;

                      return coinsB.compareTo(coinsA);
                    });

                    return SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 120), // Room for bottom nav
                      child: Column(
                        children: [
                          // --- 🏆 HERO PODIUM SECTION ---
                          Container(
                            width: double.infinity,
                            decoration: const BoxDecoration(
                              color: Color(0xFFFDF7E4), // Cream
                              borderRadius: BorderRadius.vertical(
                                bottom: Radius.circular(40),
                              ),
                            ),
                            clipBehavior: Clip.hardEdge,
                            child: _buildPodiumHero(),
                          ),

                          const SizedBox(height: 0),

                          // --- 📋 RANK LIST ---
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: docs.length,
                            itemBuilder: (context, index) {
                              final doc = docs[index];
                              final studentData = doc.data() as Map<String, dynamic>;
                              final rank = index + 1;
                              final isMe = doc.id == currentUserUid;

                              return _buildLeaderboardRow(studentData, rank, isMe);
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── HERO IMAGE ONLY ─────────────────────────────────────────────────────────

  Widget _buildPodiumHero() {
    return Container(
      width: double.infinity,
      height: 280,
      alignment: Alignment.center,
      child: SizedBox(
        width: 380, // Constrain width so it remains stable
        height: 380,
        // The 3D Podium Background Image
        child: Transform.translate(
          // Offset(X, Y)
          // X: positive moves right, negative moves left
          // Y: positive moves down, negative moves UP
          offset: const Offset(0, -40), // 👈 Change -20 to whatever pixel amount looks best!
          child: Image.asset(
            'assets/images/leaderboard.png',
            width: 150,
            height: 100,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }

  // ─── STYLIZED LIST ROWS ──────────────────────────────────────────────────────

  Widget _buildLeaderboardRow(Map<String, dynamic> studentData, int rank, bool isMe) {
    final name = studentData['name'] ?? 'Student';
    final coins = studentData['speech_coins'] ?? 0;
    String initial = name.toString().isNotEmpty ? name.toString()[0].toUpperCase() : "S";

    // 🎨 Determine card color based on the reference image
    Color bgColor;
    if (rank == 1) {
      bgColor = const Color(0xFFF3E5F5); // Light Purple
    } else if (rank == 2) {
      bgColor = const Color(0xFFFBF4D4); // Cream/Yellow
    } else if (rank == 3) {
      bgColor = const Color(0xFFE1F5FE); // Light Blue
    } else if (rank % 2 == 0) {
      bgColor = const Color(0xFFF3E5F5); // Alternate Purple
    } else {
      bgColor = const Color(0xFFFBF4D4); // Alternate Cream
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          // Medal or Number
          SizedBox(
            width: 40,
            child: _buildRankBadge(rank),
          ),

          const SizedBox(width: 8),

          // Pill Card
          Expanded(
            child: Container(
              height: 84, // Sleek pill height
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(32), // Completely rounded edges
                border: isMe ? Border.all(color: Colors.black12, width: 2) : null,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  // Avatar inside pill
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.white,
                    child: Text(
                      initial,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Name
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  // Coin & Score
                  Row(
                    children: [
                      const Icon(Icons.monetization_on, color: Colors.amber, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        "$coins",
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Beautiful badges for 1st, 2nd, 3rd, and plain text for the rest
  Widget _buildRankBadge(int rank) {
    if (rank == 1) return const Center(child: Text("🥇", style: TextStyle(fontSize: 26)));
    if (rank == 2) return const Center(child: Text("🥈", style: TextStyle(fontSize: 26)));
    if (rank == 3) return const Center(child: Text("🥉", style: TextStyle(fontSize: 26)));

    return Center(
      child: Text(
        "$rank",
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.black54,
        ),
      ),
    );
  }
}