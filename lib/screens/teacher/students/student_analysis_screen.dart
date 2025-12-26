import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:speakease/screens/student/practice/widgets/detailed_result_view.dart';

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
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("No assignments found."));

          return ListView.builder(
            padding: const EdgeInsets.all(15),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var assignmentDoc = snapshot.data!.docs[index];
              return _AssignmentAnalysisCard(
                assignmentDoc: assignmentDoc,
                studentId: studentId,
                currentTeacherId: currentTeacherId,
              );
            },
          );
        },
      ),
    );
  }
}

class _AssignmentAnalysisCard extends StatelessWidget {
  final DocumentSnapshot assignmentDoc;
  final String studentId;
  final String currentTeacherId;

  const _AssignmentAnalysisCard({
    required this.assignmentDoc,
    required this.studentId,
    required this.currentTeacherId,
  });

  @override
  Widget build(BuildContext context) {
    var data = assignmentDoc.data() as Map<String, dynamic>;
    String title = data['title'] ?? 'Untitled';
    String creatorId = data['teacher_id'] ?? '';
    bool isCreatedByMe = (creatorId == currentTeacherId);

    // Fetch the specific submission for THIS student & THIS assignment
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('submissions')
          .where('assignment_id', isEqualTo: assignmentDoc.id)
          .where('student_id', isEqualTo: studentId)
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {

        bool isDone = snapshot.hasData && snapshot.data!.docs.isNotEmpty;
        Map<String, dynamic>? subData;
        int score = 0;

        if (isDone) {
          subData = snapshot.data!.docs.first.data() as Map<String, dynamic>;
          score = subData['accuracy_score'] ?? 0;
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 15),
          elevation: isDone ? 2 : 1,
          color: isDone ? Colors.white : Colors.grey.shade50,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: isDone ? BorderSide(color: Colors.teal.withOpacity(0.3)) : BorderSide.none
          ),
          child: Padding(
            padding: const EdgeInsets.all(15.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Header Row (Title + Status)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 4),
                          // "Assigned by" logic
                          isCreatedByMe
                              ? const Text("Assigned by: You", style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold, fontSize: 12))
                              : _TeacherNameWidget(teacherId: creatorId),
                        ],
                      ),
                    ),
                    if (isDone)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(10)),
                        child: Text("Score: $score%", style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.bold, fontSize: 12)),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(10)),
                        child: Text("Pending", style: TextStyle(color: Colors.red.shade800, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                  ],
                ),

                const SizedBox(height: 15),

                // 2. Action Area
                if (isDone)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.analytics_outlined),
                      label: const Text("View Detailed Analysis"),
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.teal),
                      onPressed: () => _showDetailedReport(context, subData!),
                    ),
                  )
                else
                  const Text(
                    "Student has not completed this task yet.",
                    style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey, fontSize: 12),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Opens the exact same report view the student sees
  void _showDetailedReport(BuildContext context, Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text("Student Report", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))
              ]),
              const Divider(),

              // REUSE THE WIDGET FROM STUDENT SIDE
              DetailedResultView(
                overallScore: (data['accuracy_score'] ?? 0).toDouble(),
                fluency: (data['fluency_score'] ?? 0).toDouble(),
                pronunciation: (data['pronunciation_score'] ?? 0).toDouble(),
                clarity: (data['clarity_score'] ?? 0).toDouble(),
                accuracy: (data['transcription_accuracy'] ?? 0).toDouble(),
                wpm: (data['wpm'] ?? 0).toDouble(),
                ageGroup: data['detected_age'] ?? "Unknown",
                wordAnalysis: data['word_analysis'] ?? [],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Keep your existing TeacherNameWidget helper
class _TeacherNameWidget extends StatelessWidget {
  final String teacherId;
  const _TeacherNameWidget({required this.teacherId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(teacherId).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Text("...", style: TextStyle(fontSize: 12, color: Colors.grey));
        var data = snapshot.data!.data() as Map<String, dynamic>?;
        return Text("Assigned by: ${data?['name'] ?? 'Unknown'}", style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic, fontSize: 12));
      },
    );
  }
}