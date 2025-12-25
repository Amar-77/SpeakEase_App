import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:speakease/services/gamification_service.dart';


class PracticeSessionList extends StatefulWidget {
  final String classId;
  const PracticeSessionList({super.key, required this.classId});

  @override
  State<PracticeSessionList> createState() => _PracticeSessionListState();
}

class _PracticeSessionListState extends State<PracticeSessionList> with WidgetsBindingObserver {
  // 1. Efficient Timer Logic (Tracks screen time)
  final Stopwatch _stopwatch = Stopwatch();
  final GamificationService _gamificationService = GamificationService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _stopwatch.start();
  }

  @override
  void dispose() {
    _stopwatch.stop();
    WidgetsBinding.instance.removeObserver(this);
    _saveSessionTime();
    super.dispose();
  }

  // Handle Background/Foreground (Pause timer if app is minimized)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _stopwatch.stop();
    } else if (state == AppLifecycleState.resumed) {
      _stopwatch.start();
    }
  }

  Future<void> _saveSessionTime() async {
    int secondsSpent = _stopwatch.elapsed.inSeconds;
    if (secondsSpent > 5) {
      await _gamificationService.updateUsageTime(seconds: secondsSpent);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Practice Tasks"),
        backgroundColor: Colors.blueAccent,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('assignments')
            .where('class_id', isEqualTo: widget.classId)
            .orderBy('created_at', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No tasks assigned yet!"));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(15),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              // Using a separate widget for each card allows them to check their own status independently
              return AssignmentCard(
                  assignmentDoc: snapshot.data!.docs[index],
                  studentId: user.uid
              );
            },
          );
        },
      ),
    );
  }
}

// --- SEPARATE CARD WIDGET WITH STATUS LOGIC ---
class AssignmentCard extends StatelessWidget {
  final DocumentSnapshot assignmentDoc;
  final String studentId;

  const AssignmentCard({
    super.key,
    required this.assignmentDoc,
    required this.studentId
  });

  @override
  Widget build(BuildContext context) {
    var data = assignmentDoc.data() as Map<String, dynamic>;

    // Extract Data
    String title = data['title'] ?? 'Untitled';
    String category = data['category'] ?? 'General';
    int basePoints = data['points'] ?? 3;
    String difficulty = data['difficulty'] ?? 'Easy';

    // Difficulty Colors
    Color diffColor = difficulty == 'Hard'
        ? Colors.red
        : (difficulty == 'Medium' ? Colors.orange : Colors.green);

    // STREAMBUILDER: This implements the "Teacher Logic" on the student side
    // It listens specifically for a submission by THIS student for THIS assignment.
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('submissions')
          .where('assignment_id', isEqualTo: assignmentDoc.id)
          .where('student_id', isEqualTo: studentId)
          .snapshots(),
      builder: (context, snapshot) {

        // Determine Status
        bool isDone = false;
        int score = 0;

        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          isDone = true;
          var subData = snapshot.data!.docs.first.data() as Map<String, dynamic>;
          score = subData['accuracy_score'] ?? 0;
        }

        return Card(
          // Visual tweaks: If done, card is flatter and slightly dimmed
          elevation: isDone ? 1 : 4,
          color: isDone ? Colors.grey.shade50 : Colors.white,
          margin: const EdgeInsets.only(bottom: 15),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
              side: isDone ? BorderSide(color: Colors.green.shade200, width: 2) : BorderSide.none
          ),
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              children: [
                // --- HEADER ROW ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // LEFT: Category Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8)
                      ),
                      child: Text(
                          category.toUpperCase(),
                          style: const TextStyle(fontSize: 10, color: Colors.blue, fontWeight: FontWeight.bold)
                      ),
                    ),

                    // RIGHT: Status + Difficulty (Requested Layout)
                    Row(
                      children: [
                        // 1. Status Text & Icon
                        Text(
                          isDone ? "Done" : "Pending",
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isDone ? Colors.green : Colors.orange
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          isDone ? Icons.check_circle : Icons.pending,
                          color: isDone ? Colors.green : Colors.orange,
                          size: 16,
                        ),

                        const SizedBox(width: 10), // Space

                        // 2. Difficulty Chip
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                              color: diffColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: diffColor.withOpacity(0.5))
                          ),
                          child: Text(
                              difficulty,
                              style: TextStyle(color: diffColor, fontSize: 10, fontWeight: FontWeight.bold)
                          ),
                        ),
                      ],
                    )
                  ],
                ),

                const SizedBox(height: 10),

                // --- MAIN TITLE ---
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                      title,
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          decoration: isDone ? TextDecoration.lineThrough : null, // Strike-through if done
                          color: isDone ? Colors.grey : Colors.black
                      )
                  ),
                ),

                const SizedBox(height: 8),

                // Content Text
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                      data['content'] ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey[600])
                  ),
                ),

                const SizedBox(height: 15),

                // --- FOOTER: Coins & Action Button ---
                Row(
                  children: [
                    const Icon(Icons.monetization_on, size: 16, color: Colors.amber),
                    Text(" Reward: $basePoints Coins", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                    const Spacer(),

                    // TOGGLE: Show Score if Done, else Show "Simulate" Button
                    isDone
                        ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(20)),
                      child: Text("Score: $score%", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                    )
                        : ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))
                      ),
                      icon: const Icon(Icons.mic),
                      label: const Text("Simulate"),
                      onPressed: () => _handleSimulation(context, assignmentDoc, basePoints, studentId),
                    )
                  ],
                )
              ],
            ),
          ),
        );
      },
    );
  }

  // --- LOGIC: Handle the "Fake" Submission ---
  void _handleSimulation(BuildContext context, DocumentSnapshot doc, int basePoints, String uid) async {
    final GamificationService gamificationService = GamificationService();

    // 1. Generate Random Score (70 - 100)
    int randomScore = 70 + Random().nextInt(31);

    // 2. Show Loading SnackBar
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Analyzing Speech... 🤖"),
            duration: Duration(milliseconds: 500)
        )
    );

    // 3. Process Rewards (Calls your Service to update XP, Coins, Streak)
    Map<String, dynamic> rewards = await gamificationService.processSubmission(
      baseCoins: basePoints,
      accuracyScore: randomScore,
    );

    // 4. Save Submission to Firebase
    // (This automatically triggers the StreamBuilder above to flip the UI to "Done")
    await FirebaseFirestore.instance.collection('submissions').add({
      'assignment_id': doc.id,
      'student_id': uid,
      'submitted_at': FieldValue.serverTimestamp(),
      'audio_url': 'simulated_audio.mp3', // Dummy URL for now
      'accuracy_score': randomScore,
      'status': 'completed'
    });

    // 5. Show Success Dialog
    if (context.mounted) {
      _showRewardDialog(context, randomScore, rewards['coins'], rewards['xp']);
    }
  }

  // Helper: Pretty Dialog Box
  void _showRewardDialog(BuildContext context, int score, int coins, int xp) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Center(child: Text("Practice Complete! 🎉")),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("$score% Accuracy", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue)),
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.star, color: Colors.amber),
              Text(" +$coins Coins"),
              const SizedBox(width: 15),
              const Icon(Icons.bolt, color: Colors.orange),
              Text(" +$xp XP"),
            ]),
            const SizedBox(height: 15),
            const Text("Streak Updated! 🔥", style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Awesome!")
          )
        ],
      ),
    );
  }
}