import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:speakease/screens/student/home/profile.dart';
import 'package:speakease/screens/student/home/notification_screen.dart';
// Make sure imports point to your actual file locations

class StudentAppBar extends StatelessWidget {
  const StudentAppBar({super.key});

  Future<void> _handleNotificationClick(BuildContext context, String uid, String? classId) async {
    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => NotificationScreen(classId: classId)),
      );
    }
    // Clear the badge by updating last check time
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'last_notification_check': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
        builder: (context, userSnapshot) {
          if (!userSnapshot.hasData) return const SizedBox(height: 50);

          var userData = userSnapshot.data!.data() as Map<String, dynamic>;

          // Data Extraction
          String userName = userData['name'] ?? 'Student';
          int coins = userData['speech_coins'] ?? 0;
          String? classId = userData['class_id'];
          Timestamp lastCheck = userData['last_notification_check'] ?? Timestamp.now();

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // --- 1. NOTIFICATION BADGE ---
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('assignments')
                    .where('class_id', isEqualTo: classId)
                    .where('created_at', isGreaterThan: lastCheck)
                    .snapshots(),
                builder: (context, notifSnapshot) {
                  int count = notifSnapshot.hasData ? notifSnapshot.data!.docs.length : 0;
                  return Badge(
                    isLabelVisible: count > 0,
                    label: Text('$count', style: const TextStyle(fontSize: 10)),
                    backgroundColor: Colors.red,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.notifications_none_rounded, size: 28, color: Colors.black87),
                        onPressed: () => _handleNotificationClick(context, user.uid, classId),
                      ),
                    ),
                  );
                },
              ),

              // --- 2. COINS & PROFILE ---
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Coin Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)],
                      ),
                      child: Row(
                        children: [
                          Image.asset('assets/images/speech_coin.png', width: 24),
                          const SizedBox(width: 8),
                          Text(
                            "$coins",
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.black87),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 12),

                    // Avatar
                    GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfilePage())),
                      child: CircleAvatar(
                        radius: 22,
                        backgroundColor: Colors.white,
                        backgroundImage: const NetworkImage("https://ui-avatars.com/api/?background=random"),
                        child: Text(
                            userName.isNotEmpty ? userName[0].toUpperCase() : "S",
                            style: const TextStyle(fontWeight: FontWeight.bold)
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}