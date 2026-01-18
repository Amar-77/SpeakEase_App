import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:speakease/screens/student/home/profile.dart';
import '../practice/practice_list_screen.dart';
import '../dashboard/student_dashboard_screen.dart';
import 'notification_screen.dart';

class StudentHome extends StatelessWidget {
  const StudentHome({super.key});

  // Helper function to reset the notification count
  Future<void> _handleNotificationClick(BuildContext context, String uid, String? classId) async {
    // 1. Update the timestamp in Firestore to "now"
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'last_notification_check': FieldValue.serverTimestamp(),
    });

    // 2. Navigate to the Notification Page
    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => NotificationScreen(classId: classId),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));

        var userData = userSnapshot.data!.data() as Map<String, dynamic>;
        String? classId = userData['class_id'];
        Timestamp lastCheck = userData['last_notification_check'] ?? Timestamp.now();

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            title: const Text("SpeakEase", style: TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            elevation: 0,
            actions: [
              // 1. SpeechCoins Display
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.monetization_on, color: Colors.amber, size: 18),
                      const SizedBox(width: 4),
                      Text("${userData['speech_coins'] ?? 0}",
                          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),

              // 2. Notification Badge with Mathematical Logic
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('assignments')
                    .where('class_id', isEqualTo: classId)
                    .where('created_at', isGreaterThan: lastCheck)
                    .snapshots(),
                builder: (context, assignmentSnapshot) {
                  int unreadCount = 0;
                  if (assignmentSnapshot.hasData) {
                    unreadCount = assignmentSnapshot.data!.docs.length;
                  }

                  return Badge(
                    isLabelVisible: unreadCount > 0,
                    label: Text('$unreadCount', style: const TextStyle(fontSize: 10)),
                    alignment: const Alignment(0.7, -0.8),
                    backgroundColor: Colors.red,
                    child: IconButton(
                      icon: const Icon(Icons.notifications_none_rounded, size: 28),
                      onPressed: () => _handleNotificationClick(context, user.uid, classId),
                    ),
                  );
                },
              ),

              // 3. Profile Avatar
              GestureDetector(
                onTap: () {
                   Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfilePage()));
                },
                child: const Padding(
                  padding: EdgeInsets.only(right: 15, left: 5),
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.blueAccent,
                    child: Icon(Icons.person, size: 20, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text("Welcome back,", style: TextStyle(color: Colors.grey, fontSize: 16)),
                Text(userData['name'] ?? 'Student',
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),

                const SizedBox(height: 20),

                // --- THE GAMIFICATION CARD ---
                _buildGamificationCard(userData),

                const SizedBox(height: 30),

                // --- ACTION GRID ---
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const StudentDashboardScreen())),
                        child: _buildActionCard("View\nAnalytics", Icons.bar_chart_rounded, Colors.deepPurple),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: InkWell(
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => PracticeSessionList(classId: classId ?? ''))),
                        child: _buildActionCard("Start\nPractice", Icons.mic_rounded, Colors.teal),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- Helper Widgets ---
  Widget _buildGamificationCard(Map<String, dynamic> data) {
    int level = data['level'] ?? 1;
    int currentXp = data['current_xp'] ?? 0;
    int maxXp = data['max_xp'] ?? 1200;
    double progress = currentXp / maxXp;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.blue.shade800, Colors.blue.shade500]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(backgroundColor: Colors.white24,
                      child: Text("$level", style: const TextStyle(color: Colors.white))),
                  const SizedBox(width: 10),
                  const Text("Level Progress",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
              Text("${data['current_streak'] ?? 0} Day Streak",
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 20),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.black26,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.greenAccent),
            minHeight: 10,
          ),
          const SizedBox(height: 10),
          Text("$currentXp / $maxXp XP", style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _buildActionCard(String title, IconData icon, Color color) {
    return Container(
      height: 120,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 40, color: color),
          const Spacer(),
          Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}