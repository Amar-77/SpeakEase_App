import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:speakease/screens/student/home/widgets/student_app_bar.dart';

// 1. Data Model (Kept inside for simplicity)
class Achievement {
  final String id;
  final String title;
  final String description;
  final IconData iconData; // Changed to IconData for easier default UI
  final Color color;
  final int requiredValue;
  final String type; // 'streak', 'level', 'coins', 'xp'

  Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.iconData,
    required this.color,
    required this.requiredValue,
    required this.type,
  });
}

class AchievementsScreen extends StatelessWidget {
  // We removed 'userData' from constructor because we fetch it live now!
  const AchievementsScreen({super.key, Map<String, dynamic>? userData});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    // 2. Define Achievements List
    final List<Achievement> allAchievements = [
      Achievement(
        id: 'streak_3',
        title: 'On Fire!',
        description: 'Reach a 3-day streak',
        iconData: Icons.local_fire_department,
        color: Colors.orange,
        requiredValue: 3,
        type: 'streak',
      ),
      Achievement(
        id: 'streak_7',
        title: 'Unstoppable',
        description: 'Reach a 7-day streak',
        iconData: Icons.whatshot,
        color: Colors.deepOrange,
        requiredValue: 7,
        type: 'streak',
      ),
      Achievement(
        id: 'level_5',
        title: 'Rising Star',
        description: 'Reach Level 5',
        iconData: Icons.star,
        color: Colors.amber,
        requiredValue: 5,
        type: 'level',
      ),
      Achievement(
        id: 'coins_100',
        title: 'First Earnings',
        description: 'Earn 100 Speech Coins',
        iconData: Icons.monetization_on,
        color: Colors.yellow.shade700,
        requiredValue: 100,
        type: 'coins',
      ),
      Achievement(
        id: 'coins_1000',
        title: 'Wealthy Words',
        description: 'Earn 1000 Speech Coins',
        iconData: Icons.savings,
        color: Colors.green,
        requiredValue: 1000,
        type: 'coins',
      ),
      Achievement(
        id: 'xp_500',
        title: 'Knowledge Seeker',
        description: 'Gain 500 XP',
        iconData: Icons.school,
        color: Colors.blue,
        requiredValue: 500,
        type: 'xp',
      ),
    ];

    if (user == null) return const SizedBox();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // 🔥 NEW: SHARED APP BAR
            const StudentAppBar(),

            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Text("Achievements", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            ),

            // 🔥 NEW: LIVE STREAM BUILDER
            Expanded(
              child: StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                  var data = snapshot.data!.data() as Map<String, dynamic>;

                  return GridView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 100), // Bottom padding for nav bar
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 15,
                      mainAxisSpacing: 15,
                      childAspectRatio: 0.85,
                    ),
                    itemCount: allAchievements.length,
                    itemBuilder: (context, index) {
                      final achievement = allAchievements[index];
                      final isUnlocked = _checkUnlocked(achievement, data);

                      return _buildAchievementCard(achievement, isUnlocked);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 3. Helper to Check Logic
  bool _checkUnlocked(Achievement achievement, Map<String, dynamic> data) {
    int userValue = 0;
    switch (achievement.type) {
      case 'streak':
        userValue = data['current_streak'] ?? 0;
        break;
      case 'level':
        userValue = data['level'] ?? 1;
        break;
      case 'coins':
        userValue = data['speech_coins'] ?? 0;
        break;
      case 'xp':
        userValue = data['current_xp'] ?? 0;
        break;
    }
    return userValue >= achievement.requiredValue;
  }

  // 4. UI Card Builder
  Widget _buildAchievementCard(Achievement item, bool isUnlocked) {
    return Container(
      decoration: BoxDecoration(
        color: isUnlocked ? Colors.white : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(24),
        border: isUnlocked
            ? Border.all(color: item.color.withOpacity(0.3), width: 2)
            : Border.all(color: Colors.grey.shade200),
        boxShadow: isUnlocked
            ? [BoxShadow(color: item.color.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))]
            : [],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon Circle
          Container(
            height: 70, width: 70,
            decoration: BoxDecoration(
              color: isUnlocked ? item.color.withOpacity(0.1) : Colors.grey.shade200,
              shape: BoxShape.circle,
            ),
            child: Icon(
              item.iconData,
              size: 35,
              color: isUnlocked ? item.color : Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 15),

          // Title
          Text(
            item.title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: isUnlocked ? Colors.black87 : Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 5),

          // Description
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Text(
              item.description,
              style: TextStyle(
                fontSize: 11,
                color: isUnlocked ? Colors.black54 : Colors.grey.shade400,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 10),

          // Status Badge
          if (!isUnlocked)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock, size: 10, color: Colors.grey),
                  SizedBox(width: 4),
                  Text("LOCKED", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey)),
                ],
              ),
            )
          else
            Icon(Icons.check_circle, color: item.color, size: 22)
        ],
      ),
    );
  }
}