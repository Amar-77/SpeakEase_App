import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:speakease/screens/student/practice/widgets/detailed_result_view.dart';

class StudentAnalysisScreen extends StatefulWidget {
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
  State<StudentAnalysisScreen> createState() =>
      _StudentAnalysisScreenState();
}

class _StudentAnalysisScreenState extends State<StudentAnalysisScreen> {
  final PageController _pageController = PageController();
  bool isShowingCompleted = false;

  @override
  Widget build(BuildContext context) {
    final String currentTeacherId =
        FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: Colors.white,

      /// APP BAR
      appBar: AppBar(
        title: Text("${widget.studentName}'s Progress"),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),

      body: Column(
        children: [

          /// 🔥 TOGGLE
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Container(
              width: 260,
              height: 50,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Stack(
                children: [

                  /// SLIDING INDICATOR
                  AnimatedAlign(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    alignment: isShowingCompleted
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      width: 120,
                      decoration: BoxDecoration(
                        color: isShowingCompleted
                            ? Colors.green
                            : Colors.white,
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                  ),

                  /// LABELS
                  Row(
                    children: [

                      /// PENDING
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            _pageController.animateToPage(
                              0,
                              duration:
                                  const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          },
                          child: Center(
                            child: Text(
                              "Pending",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isShowingCompleted
                                    ? Colors.white70
                                    : Colors.black,
                              ),
                            ),
                          ),
                        ),
                      ),

                      /// COMPLETED
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            _pageController.animateToPage(
                              1,
                              duration:
                                  const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          },
                          child: Center(
                            child: Text(
                              "Completed",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isShowingCompleted
                                    ? Colors.white
                                    : Colors.white70,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          /// 🔥 PAGEVIEW
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  isShowingCompleted = index == 1;
                });
              },
              children: [

                /// 🔴 PENDING
                _buildAssignmentList(
                  isCompletedPage: false,
                  currentTeacherId: currentTeacherId,
                ),

                /// 🟢 COMPLETED
                _buildAssignmentList(
                  isCompletedPage: true,
                  currentTeacherId: currentTeacherId,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 🔥 LIST BUILDER
  Widget _buildAssignmentList({
    required bool isCompletedPage,
    required String currentTeacherId,
  }) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('assignments')
          .where('class_id', isEqualTo: widget.classId)
          .orderBy('created_at', descending: true)
          .snapshots(),
      builder: (context, snapshot) {

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("No assignments found."));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(15),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {

            var assignmentDoc = snapshot.data!.docs[index];

            return _FilteredAssignmentCard(
              assignmentDoc: assignmentDoc,
              studentId: widget.studentId,
              currentTeacherId: currentTeacherId,
              showCompleted: isCompletedPage,
            );
          },
        );
      },
    );
  }
}

/// 🔥 FILTER WRAPPER
class _FilteredAssignmentCard extends StatelessWidget {
  final DocumentSnapshot assignmentDoc;
  final String studentId;
  final String currentTeacherId;
  final bool showCompleted;

  const _FilteredAssignmentCard({
    required this.assignmentDoc,
    required this.studentId,
    required this.currentTeacherId,
    required this.showCompleted,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('submissions')
          .where('assignment_id', isEqualTo: assignmentDoc.id)
          .where('student_id', isEqualTo: studentId)
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {

        bool isDone =
            snapshot.hasData && snapshot.data!.docs.isNotEmpty;

        if (showCompleted != isDone) {
          return const SizedBox.shrink();
        }

        return _AssignmentAnalysisCard(
          assignmentDoc: assignmentDoc,
          studentId: studentId,
          currentTeacherId: currentTeacherId,
        );
      },
    );
  }
}

/// 🔥 CARD (UI ONLY UPDATED)
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

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('submissions')
          .where('assignment_id', isEqualTo: assignmentDoc.id)
          .where('student_id', isEqualTo: studentId)
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {

        bool isDone =
            snapshot.hasData && snapshot.data!.docs.isNotEmpty;

        Map<String, dynamic>? subData;
        int score = 0;

        if (isDone) {
          subData =
              snapshot.data!.docs.first.data() as Map<String, dynamic>;
          score = subData['accuracy_score'] ?? 0;
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 15),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                /// TITLE + CONTENT
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [

                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16),
                          ),

                          const SizedBox(height: 6),

                          Text(
                            data['content'] ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (isDone)
                      Text("Score: $score%")
                    else
                      Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: Colors.red.shade100, // light red bg
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      "Pending",
      style: TextStyle(
        color: Colors.red.shade800,
        fontWeight: FontWeight.bold,
        fontSize: 12,
      ),
    ),
  ),
                  ],
                ),

                const SizedBox(height: 10),

                /// 🔥 ORIGINAL BUTTON (UNCHANGED)
                if (isDone)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.analytics_outlined),
                    label: const Text("View Detailed Analysis"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.teal,
                    ),
                    onPressed: () => _showDetailedReport(context, subData!),
                  )
                else
                  const Text(
                    "Student has not completed this task yet.",
                    style: TextStyle(
                        fontStyle: FontStyle.italic,
                        color: Colors.grey,
                        fontSize: 12),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 🔥 ORIGINAL REPORT FUNCTION (UNCHANGED)
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
              Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Student Report",
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold)),
                    IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context))
                  ]),
              const Divider(),

              DetailedResultView(
                overallScore: (data['accuracy_score'] ?? 0).toDouble(),
                fluency: (data['fluency_score'] ?? 0).toDouble(),
                pronunciation:
                    (data['pronunciation_score'] ?? 0).toDouble(),
                clarity: (data['clarity_score'] ?? 0).toDouble(),
                accuracy:
                    (data['transcription_accuracy'] ?? 0).toDouble(),
                wpm: (data['wpm'] ?? 0).toDouble(),
                ageGroup: data['detected_age'] ?? "Unknown",
                wordAnalysis: data['word_analysis'] ?? [],
                userTranscription: data['full_transcription'] ?? "",
              ),
            ],
          ),
        ),
      ),
    );
  }
}