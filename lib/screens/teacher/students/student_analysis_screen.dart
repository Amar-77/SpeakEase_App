import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StudentAnalysisScreen extends StatelessWidget {
  final String studentId;
  final String studentName;
  final String classId;

  const StudentAnalysisScreen({
    super.key,
    required this.studentId,
    required this.studentName,
    required this.classId,
  });

  @override
  Widget build(BuildContext context) {
    // Get the ID of the teacher currently looking at this screen
    final String currentTeacherId = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: Text("$studentName's Progress"),
        backgroundColor: Colors.teal,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('assignments')
            .where('class_id', isEqualTo: classId)
            .orderBy('created_at', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No assignments created for this class yet."));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(15),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var assignmentDoc = snapshot.data!.docs[index];
              var assignmentData = assignmentDoc.data() as Map<String, dynamic>;

              // LOGIC: Check who created this assignment
              String creatorId = assignmentData['teacher_id'] ?? '';
              bool isCreatedByMe = (creatorId == currentTeacherId);

              return Card(
                margin: const EdgeInsets.only(bottom: 15),
                child: Padding(
                  padding: const EdgeInsets.all(15.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  assignmentData['title'],
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                const SizedBox(height: 4),

                                // --- NEW LOGIC: SHOW TEACHER NAME ---
                                isCreatedByMe
                                    ? const Text(
                                  "Assigned by: You",
                                  style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold, fontSize: 12),
                                )
                                    : _TeacherNameWidget(teacherId: creatorId), // Fetch name if not me
                              ],
                            ),
                          ),

                          // The Badge Widget
                          _SubmissionStatusChip(
                            assignmentId: assignmentDoc.id,
                            studentId: studentId,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// --- HELPER 1: Fetches Teacher Name for "Assigned by X" ---
class _TeacherNameWidget extends StatelessWidget {
  final String teacherId;
  const _TeacherNameWidget({required this.teacherId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(teacherId).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Text("Assigned by: Loading...", style: TextStyle(fontSize: 12, color: Colors.grey));

        var data = snapshot.data!.data() as Map<String, dynamic>?;
        String name = data?['name'] ?? 'Unknown Teacher';

        return Text(
          "Assigned by: $name",
          style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic, fontSize: 12),
        );
      },
    );
  }
}

// --- HELPER 2: Check Submission Status (Unchanged) ---
class _SubmissionStatusChip extends StatelessWidget {
  final String assignmentId;
  final String studentId;

  const _SubmissionStatusChip({required this.assignmentId, required this.studentId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('submissions')
          .where('assignment_id', isEqualTo: assignmentId)
          .where('student_id', isEqualTo: studentId)
          .limit(1)
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2));
        }

        bool isDone = snapshot.hasData && snapshot.data!.docs.isNotEmpty;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isDone ? Colors.green.shade100 : Colors.red.shade100,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isDone ? Colors.green : Colors.red),
          ),
          child: Row(
            children: [
              Icon(
                isDone ? Icons.check_circle : Icons.pending,
                size: 16,
                color: isDone ? Colors.green.shade800 : Colors.red.shade800,
              ),
              const SizedBox(width: 5),
              Text(
                isDone ? "Done" : "Pending",
                style: TextStyle(
                  color: isDone ? Colors.green.shade800 : Colors.red.shade800,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}