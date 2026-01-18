import 'package:flutter/material.dart';

// 1. Define the Data Model
class Achievement {
  final String id;
  final String title;
  final String description;
  final String iconPath;
  final int requiredValue;
  final String type; // 'streak', 'level', 'coins'

  Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.iconPath,
    required this.requiredValue,
    required this.type,
  });
}

class AchievementsScreen extends StatelessWidget {
  final Map<String, dynamic> userData;

  AchievementsScreen({super.key, required this.userData});

  // 2. Define the List of Available Achievements
  final List<Achievement> allAchievements = [
    Achievement(
      id: 'streak_3',
      title: 'On Fire!',
      description: 'Reach a 3-day streak',
      iconPath: 'assets/images/badge_fire.png', // You need to add these images
      requiredValue: 3,
      type: 'streak',
    ),
    Achievement(
      id: 'level_5',
      title: 'Rising Star',
      description: 'Reach Level 5',
      iconPath: 'assets/images/badge_star.png',
      requiredValue: 5,
      type: 'level',
    ),
    Achievement(
      id: 'coins_1000',
      title: 'Wealthy Words',
      description: 'Earn 1000 Speech Coins',
      iconPath: 'assets/images/badge_coin.png',
      requiredValue: 4,
      type: 'coins',
    ),
    Achievement(
      id: 'xp_500',
      title: 'Knowledge Seeker',
      description: 'Gain 500 XP',
      iconPath: 'assets/images/badge_book.png',
      requiredValue: 500,
      type: 'xp',
    ),
  ];

  // 3. Helper to check if unlocked
  bool _isUnlocked(Achievement achievement) {
    int userValue = 0;

    switch (achievement.type) {
      case 'streak':
        userValue = userData['current_streak'] ?? 0;
        break;
      case 'level':
        userValue = userData['level'] ?? 1;
        break;
      case 'coins':
        userValue = userData['speech_coins'] ?? 0;
        break;
      case 'xp':
        userValue = userData['current_xp'] ?? 0;
        break;
      default:
        userValue = 0;
    }
    return userValue >= achievement.requiredValue;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Achievements",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(20),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 15,
          mainAxisSpacing: 15,
          childAspectRatio: 0.85,
        ),
        itemCount: allAchievements.length,
        itemBuilder: (context, index) {
          final achievement = allAchievements[index];
          final isUnlocked = _isUnlocked(achievement);

          return Container(
            decoration: BoxDecoration(
              color: isUnlocked ? const Color(0xFFF3E5F5) : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(24),
              border: isUnlocked
                  ? Border.all(color: Colors.purple.shade200, width: 2)
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Badge Image
                Opacity(
                  opacity: isUnlocked ? 1.0 : 0.4,
                  child: Image.asset(
                    achievement.iconPath,
                    height: 80,
                    width: 80,
                    fit: BoxFit.contain,
                    // Placeholder icon if asset is missing
                    errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.emoji_events,
                        size: 60,
                        color: isUnlocked ? Colors.amber : Colors.grey
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                // Title
                Text(
                  achievement.title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isUnlocked ? Colors.black87 : Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 5),
                // Description
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(
                    achievement.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: isUnlocked ? Colors.black54 : Colors.grey.shade400,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 10),
                // Locked/Unlocked Status
                if (!isUnlocked)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text("LOCKED", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                  )
                else
                  const Icon(Icons.check_circle, color: Colors.green, size: 20)
              ],
            ),
          );
        },
      ),
    );
  }
}