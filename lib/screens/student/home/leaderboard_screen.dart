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
      backgroundColor: const Color(0xFFFFF9C4), // Light Cream background
      body: SafeArea(
        child: Column(
          children: [
            // 1. 🔥 NEW SHARED APP BAR (Replaces standard AppBar)
            const StudentAppBar(),

            // 2. Title Section (Since we removed the standard AppBar title)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 15.0),
              child: Text(
                "Class Leaderboard",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),

            // 3. Main Content
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                // Fetch ALL students (to include those with 0 coins)
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
                    return const Center(child: Text("No students found in this class yet!"));
                  }

                  // 4. Client-Side Sorting
                  docs.sort((a, b) {
                    final dataA = a.data() as Map<String, dynamic>;
                    final dataB = b.data() as Map<String, dynamic>;

                    int coinsA = dataA['speech_coins'] ?? 0;
                    int coinsB = dataB['speech_coins'] ?? 0;

                    return coinsB.compareTo(coinsA); // Descending
                  });

                  final topThree = docs.take(3).toList();
                  final restOfList = docs.skip(3).toList();

                  return Column(
                    children: [
                      // --- PODIUM SECTION (Top 3) ---
                      Container(
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(40),
                            bottomRight: Radius.circular(40),
                          ),
                          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 5))],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            // 2nd Place (Left)
                            if (topThree.length >= 2)
                              _buildPodiumSpot(context, topThree[1], 2, 140, Colors.grey.shade300),
                            // 1st Place (Center)
                            if (topThree.isNotEmpty)
                              _buildPodiumSpot(context, topThree[0], 1, 180, const Color(0xFFFFD700)),
                            // 3rd Place (Right)
                            if (topThree.length >= 3)
                              _buildPodiumSpot(context, topThree[2], 3, 120, const Color(0xFFCD7F32)),
                          ],
                        ),
                      ),

                      const SizedBox(height: 10),

                      // --- RANK LIST (Everyone else) ---
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 10, 20, 100), // Bottom padding for floating nav
                          itemCount: restOfList.length,
                          itemBuilder: (context, index) {
                            final doc = restOfList[index];
                            final studentData = doc.data() as Map<String, dynamic>;

                            final rank = index + 4;
                            final isMe = doc.id == currentUserUid;
                            final coins = studentData['speech_coins'] ?? 0;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: isMe ? Colors.purple.shade50 : Colors.white,
                                borderRadius: BorderRadius.circular(15),
                                border: isMe ? Border.all(color: Colors.purple, width: 2) : null,
                                boxShadow: [
                                  BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 5, offset: const Offset(0, 2))
                                ],
                              ),
                              child: ListTile(
                                leading: Container(
                                  width: 40, height: 40,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text("#$rank", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                                ),
                                title: Text(
                                  studentData['name'] ?? 'Unknown',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF9C4),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.monetization_on, color: Colors.amber, size: 18),
                                      const SizedBox(width: 4),
                                      Text("$coins", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper Widget for Podium Users (Kept EXACTLY same)
  Widget _buildPodiumSpot(BuildContext context, DocumentSnapshot doc, int rank, double height, Color color) {
    final data = doc.data() as Map<String, dynamic>;
    final name = data['name'] ?? 'Student';
    final coins = data['speech_coins'] ?? 0;

    String firstName = "S";
    if (name.toString().isNotEmpty) {
      firstName = name.toString().split(' ')[0];
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        CircleAvatar(
          radius: rank == 1 ? 35 : 25,
          backgroundColor: color,
          child: CircleAvatar(
            radius: rank == 1 ? 32 : 22,
            backgroundColor: Colors.white,
            backgroundImage: const NetworkImage("https://ui-avatars.com/api/?background=random"),
            child: Text(firstName.isNotEmpty ? firstName[0] : "S", style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 8),
        Text(firstName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.monetization_on, size: 12, color: Colors.amber),
            Text("$coins", style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: rank == 1 ? 90 : 70,
          height: height * 0.6,
          decoration: BoxDecoration(
            color: color.withOpacity(0.3),
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(10), topRight: Radius.circular(10)),
            border: Border.all(color: color, width: 2),
          ),
          alignment: Alignment.center,
          child: Text("$rank", style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: color.withOpacity(0.8))),
        ),
      ],
    );
  }
}