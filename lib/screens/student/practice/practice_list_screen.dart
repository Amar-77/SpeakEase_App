import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:speakease/services/gamification_service.dart';
import 'widgets/assignment_card.dart';

class PracticeSessionList extends StatefulWidget {
  final String classId;
  const PracticeSessionList({super.key, required this.classId});

  @override
  State<PracticeSessionList> createState() => _PracticeSessionListState();
}

class _PracticeSessionListState extends State<PracticeSessionList> with WidgetsBindingObserver {
  final Stopwatch _stopwatch = Stopwatch();
  final GamificationService _gamificationService = GamificationService();

  bool isShowingCompleted = false;

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
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && _stopwatch.elapsed.inSeconds > 5) {
      // ⏱️ UPDATED: Pass User ID and seconds to helper
      await _gamificationService.updateUsageTime(
          userId: user.uid,
          seconds: _stopwatch.elapsed.inSeconds
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Assignments", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildToggleOption("Incompleted", !isShowingCompleted),
                const SizedBox(width: 10),
                _buildToggleOption("Completed", isShowingCompleted),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('assignments')
                  .where('class_id', isEqualTo: widget.classId)
                  .orderBy('created_at', descending: true)
                  .snapshots(),
              builder: (context, assignmentSnapshot) {
                if (assignmentSnapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (!assignmentSnapshot.hasData || assignmentSnapshot.data!.docs.isEmpty) return const Center(child: Text("No tasks assigned yet!"));

                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('submissions')
                      .where('student_id', isEqualTo: user.uid)
                      .snapshots(),
                  builder: (context, subSnapshot) {
                    if (subSnapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

                    final submittedIds = subSnapshot.data?.docs
                        .map((d) => (d.data() as Map<String, dynamic>)['assignment_id'].toString())
                        .toSet() ?? {};

                    final filteredDocs = assignmentSnapshot.data!.docs.where((doc) {
                      bool isDone = submittedIds.contains(doc.id);
                      return isShowingCompleted ? isDone : !isDone;
                    }).toList();

                    if (filteredDocs.isEmpty) {
                      return Center(child: Text(isShowingCompleted ? "No completed tasks yet!" : "All tasks completed! 🎉"));
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(15),
                      itemCount: filteredDocs.length,
                      itemBuilder: (context, index) {
                        return AssignmentCard(
                          assignmentDoc: filteredDocs[index],
                          studentId: user.uid,
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleOption(String label, bool isActive) {
    return GestureDetector(
      onTap: () => setState(() => isShowingCompleted = (label == "Completed")),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
          border: isActive ? Border.all(color: Colors.black26) : null,
          boxShadow: isActive ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))] : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.black : Colors.grey,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}