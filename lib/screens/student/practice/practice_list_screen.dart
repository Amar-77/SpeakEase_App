import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:speakease/services/gamification_service.dart';
import 'widgets/assignment_card.dart'; // Import Card

class PracticeSessionList extends StatefulWidget {
  final String classId;
  const PracticeSessionList({super.key, required this.classId});

  @override
  State<PracticeSessionList> createState() => _PracticeSessionListState();
}

class _PracticeSessionListState extends State<PracticeSessionList> with WidgetsBindingObserver {
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) _stopwatch.stop();
    else if (state == AppLifecycleState.resumed) _stopwatch.start();
  }

  Future<void> _saveSessionTime() async {
    if (_stopwatch.elapsed.inSeconds > 5) {
      // THIS UPDATES THE USAGE TIME IN FIRESTORE
      await _gamificationService.updateUsageTime(seconds: _stopwatch.elapsed.inSeconds);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;

    return Scaffold(
      appBar: AppBar(title: const Text("Practice Tasks"), backgroundColor: Colors.blueAccent),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('assignments')
            .where('class_id', isEqualTo: widget.classId)
            .orderBy('created_at', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("No tasks assigned yet!"));

          return ListView.builder(
            padding: const EdgeInsets.all(15),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              return AssignmentCard(
                assignmentDoc: snapshot.data!.docs[index],
                studentId: user.uid,
              );
            },
          );
        },
      ),
    );
  }
}