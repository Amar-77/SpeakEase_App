import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GamificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ONE FUNCTION TO RULE THEM ALL (Coins, XP, Streak, Time)
  Future<Map<String, dynamic>> processSubmission({
    required String userId,        // 👈 ADDED: Required for Firestore lookup
    required int baseCoins,
    required int accuracyScore,
    required int durationSeconds,
  }) async {
    // If no user is logged in, we can't update anything.
    if (_auth.currentUser == null) return {};

    // --- 1. CALCULATE REWARDS ---
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

    // --- 2. PREPARE DATES ---
    DateTime now = DateTime.now();
    // Create "Midnight" objects for accurate day comparison
    DateTime today = DateTime(now.year, now.month, now.day);
    DateTime yesterday = today.subtract(const Duration(days: 1));

    // Format for storage string (e.g., "2026-2-16")
    String todayStr = "${now.year}-${now.month}-${now.day}";

    DocumentReference userRef = _firestore.collection('users').doc(userId);

    return _firestore.runTransaction((transaction) async {
      DocumentSnapshot snapshot = await transaction.get(userRef);
      if (!snapshot.exists) throw Exception("User not found");

      Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;

      // --- 3. STREAK LOGIC ---
      int currentStreak = data['current_streak'] ?? 0;
      String lastActiveStr = data['last_active_date'] ?? '';

      DateTime? lastActiveDate;
      try {
        List<String> parts = lastActiveStr.split('-');
        if (parts.length == 3) {
          lastActiveDate = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
        }
      } catch (e) {
        // Invalid date format, treat as null
      }

      bool isStreakBonus = false;

      if (lastActiveDate == null) {
        currentStreak = 1; // First ever game
      } else if (today.isAtSameMomentAs(lastActiveDate)) {
        // Already played today -> Streak stays same
        isStreakBonus = true;
      } else if (yesterday.isAtSameMomentAs(lastActiveDate)) {
        // Played yesterday -> Streak INCREASES! 🔥
        currentStreak += 1;
        isStreakBonus = true;
      } else {
        // Missed a day -> Streak RESETS 😢
        currentStreak = 1;
      }

      // --- 4. LEVEL UP LOGIC ---
      int currentCoins = data['speech_coins'] ?? 0;
      int currentXp = data['current_xp'] ?? 0;
      int level = data['level'] ?? 1;
      int maxXp = data['max_xp'] ?? 1200;

      int newCoins = currentCoins + coinsEarned;
      int newXp = currentXp + xpEarned;
      int newLevel = level;
      int newMaxXp = maxXp;

      if (newXp >= maxXp) {
        newLevel = level + 1;
        newXp = newXp - maxXp;
        newMaxXp = (newMaxXp * 1.2).toInt();
      }

      // --- 5. TIME CALCULATION ---
      double minutesToAdd = durationSeconds / 60.0;
      double totalMinutes = (data['total_practice_minutes'] ?? 0.0).toDouble();

      // --- 6. COMMIT UPDATES ---
      transaction.update(userRef, {
        'speech_coins': newCoins,
        'current_xp': newXp,
        'level': newLevel,
        'max_xp': newMaxXp,
        'current_streak': currentStreak,
        'last_active_date': todayStr,
        'total_practice_minutes': totalMinutes + minutesToAdd,
      });

      // Update Daily Stats
      DocumentReference statsRef = userRef.collection('daily_stats').doc(todayStr);
      transaction.set(statsRef, {
        'date': todayStr,
        'tasks_completed': FieldValue.increment(1),
        'coins_earned': FieldValue.increment(coinsEarned),
        'accuracy_sum': FieldValue.increment(accuracyScore),
        'minutes_spent': FieldValue.increment(minutesToAdd),
      }, SetOptions(merge: true));

      return {
        'xp': xpEarned,
        'coins': coinsEarned,
        'score': accuracyScore,
        'streak': currentStreak,
        'streak_bonus': isStreakBonus, // Return for UI popup
        'leveledUp': newLevel > level
      };
    });
  }

  // Helper for Session Time (Used in List Page)
  Future<void> updateUsageTime({required String userId, required int seconds}) async {
    if (seconds < 5) return; // Ignore very short sessions

    DocumentReference userRef = _firestore.collection('users').doc(userId);
    DateTime now = DateTime.now();
    String todayStr = "${now.year}-${now.month}-${now.day}";
    double minutes = seconds / 60.0;

    await _firestore.runTransaction((transaction) async {
      transaction.update(userRef, {
        'total_practice_minutes': FieldValue.increment(minutes)
      });

      DocumentReference statsRef = userRef.collection('daily_stats').doc(todayStr);
      transaction.set(statsRef, {
        'minutes_spent': FieldValue.increment(minutes)
      }, SetOptions(merge: true));
    });
  }

  // 🚀 NEW: Run this when the app starts (StudentHome initState)
  Future<void> checkStreakOnStartup() async {
    User? user = _auth.currentUser;
    if (user == null) return;

    DocumentReference userRef = _firestore.collection('users').doc(user.uid);

    // We use a transaction to be safe, though a simple get/update works too
    await _firestore.runTransaction((transaction) async {
      DocumentSnapshot snapshot = await transaction.get(userRef);
      if (!snapshot.exists) return;

      Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;

      String lastActiveStr = data['last_active_date'] ?? '';
      int currentStreak = data['current_streak'] ?? 0;

      // If they have no streak, nothing to reset
      if (currentStreak == 0) return;

      // Parse Dates
      DateTime now = DateTime.now();
      DateTime today = DateTime(now.year, now.month, now.day);
      DateTime yesterday = today.subtract(const Duration(days: 1));

      DateTime? lastActiveDate;
      try {
        List<String> parts = lastActiveStr.split('-');
        if (parts.length == 3) {
          lastActiveDate = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
        }
      } catch (e) {
        return; // Invalid date format, safety exit
      }

      if (lastActiveDate == null) return;

      // 🔍 THE LOGIC:
      // If last active date was BEFORE yesterday (e.g., 2 days ago),
      // they missed a day. Reset to 0.
      if (lastActiveDate.isBefore(yesterday)) {
        transaction.update(userRef, {
          'current_streak': 0,
          // We DO NOT update 'last_active_date' here.
          // That only updates when they actually practice!
        });
        print("💔 Streak broken! Resetting to 0.");
      } else {
        print("🔥 Streak is safe.");
      }
    });
  }
}