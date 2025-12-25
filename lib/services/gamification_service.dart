import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GamificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 1. PROCESS SUBMISSION (Coins, XP, Streak)
  Future<Map<String, dynamic>> processSubmission({
    required int baseCoins,
    required int accuracyScore,
  }) async {
    User? user = _auth.currentUser;
    if (user == null) return {};

    // --- A. CALCULATE REWARDS ---
    int xpEarned = 0;
    int coinsEarned = baseCoins;

    if (accuracyScore >= 90) {
      xpEarned = 100;
      coinsEarned += 2; // Bonus
    } else if (accuracyScore >= 80) {
      xpEarned = 70;
      coinsEarned += 1;
    } else {
      xpEarned = 40;
    }

    DocumentReference userRef = _firestore.collection('users').doc(user.uid);
    DateTime now = DateTime.now();
    String todayDate = "${now.year}-${now.month}-${now.day}";

    await _firestore.runTransaction((transaction) async {
      DocumentSnapshot snapshot = await transaction.get(userRef);
      if (!snapshot.exists) return;

      Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;

      int currentCoins = data['speech_coins'] ?? 0;
      int currentXp = data['current_xp'] ?? 0;
      int level = data['level'] ?? 1;
      int maxXp = data['max_xp'] ?? 1200;

      int newCoins = currentCoins + coinsEarned;
      int newXp = currentXp + xpEarned;
      int newLevel = level;
      int newMaxXp = maxXp;

      // Level Up Logic
      if (newXp >= maxXp) {
        newLevel = level + 1;
        newXp = newXp - maxXp;
        newMaxXp = (newMaxXp * 1.2).toInt();
      }

      // Streak Logic
      int streak = data['current_streak'] ?? 0;
      String lastActive = data['last_active_date'] ?? '';

      if (lastActive != todayDate) {
        streak += 1;
      }

      // Update User
      transaction.update(userRef, {
        'speech_coins': newCoins,
        'current_xp': newXp,
        'level': newLevel,
        'max_xp': newMaxXp,
        'current_streak': streak,
        'last_active_date': todayDate,
      });

      // Update Daily Stats (Tasks & Coins)
      DocumentReference statsRef = userRef.collection('daily_stats').doc(todayDate);
      transaction.set(statsRef, {
        'date': todayDate,
        'tasks_completed': FieldValue.increment(1),
        'coins_earned': FieldValue.increment(coinsEarned),
        'accuracy_sum': FieldValue.increment(accuracyScore),
      }, SetOptions(merge: true));
    });

    return {
      'xp': xpEarned,
      'coins': coinsEarned,
      'score': accuracyScore
    };
  }

  // 2. UPDATE USAGE TIME (The missing function!)
  Future<void> updateUsageTime({required int seconds}) async {
    User? user = _auth.currentUser;
    if (user == null) return;

    // Convert seconds to minutes (minimum 1 minute to record)
    int minutes = (seconds / 60).round();
    if (minutes < 1) return;

    DocumentReference userRef = _firestore.collection('users').doc(user.uid);
    DateTime now = DateTime.now();
    String todayDate = "${now.year}-${now.month}-${now.day}";

    await _firestore.runTransaction((transaction) async {
      // Update Lifetime Stats
      transaction.update(userRef, {
        'total_practice_minutes': FieldValue.increment(minutes),
      });

      // Update Daily Stats (For the Dashboard Graph)
      DocumentReference statsRef = userRef.collection('daily_stats').doc(todayDate);
      transaction.set(statsRef, {
        'date': todayDate,
        'minutes_spent': FieldValue.increment(minutes),
      }, SetOptions(merge: true));
    });
  }
}