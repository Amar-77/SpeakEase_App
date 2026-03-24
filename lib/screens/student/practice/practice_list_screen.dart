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

class _PracticeSessionListState extends State<PracticeSessionList>
    with WidgetsBindingObserver {

  final Stopwatch _stopwatch = Stopwatch();
  final GamificationService _gamificationService = GamificationService();

  final PageController _pageController = PageController();

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
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _stopwatch.stop();
    } else if (state == AppLifecycleState.resumed) {
      _stopwatch.start();
    }
  }

  Future<void> _saveSessionTime() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && _stopwatch.elapsed.inSeconds > 5) {
      await _gamificationService.updateUsageTime(
        userId: user.uid,
        seconds: _stopwatch.elapsed.inSeconds,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 255, 255, 255),
      appBar: AppBar(
        title: const Text(
          "Assignments",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color.fromARGB(255, 255, 255, 255),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Column(
        children: [

          /// 🔥 TOGGLE (SYNC WITH PAGEVIEW)
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

                  /// MOVING PILL
                  AnimatedAlign(
                    duration: const Duration(milliseconds: 200),
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

                  /// TEXT
                  Row(
                    children: [

                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            _pageController.animateToPage(
                              0,
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          },
                          child: Center(
                            child: Text(
                              "Incomplete",
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

                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            _pageController.animateToPage(
                              1,
                              duration: const Duration(milliseconds: 300),
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

          /// 🔥 PAGEVIEW (MAIN CHANGE)
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  isShowingCompleted = index == 1;
                });
              },
              children: [

                /// INCOMPLETE PAGE
                _buildAssignmentList(isCompletedPage: false),

                /// COMPLETED PAGE
                _buildAssignmentList(isCompletedPage: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 🔥 LIST BUILDER (UNCHANGED LOGIC)
  Widget _buildAssignmentList({required bool isCompletedPage}) {
    final user = FirebaseAuth.instance.currentUser!;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('assignments')
          .where('class_id', isEqualTo: widget.classId)
          .orderBy('created_at', descending: true)
          .snapshots(),
      builder: (context, assignmentSnapshot) {
        if (assignmentSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!assignmentSnapshot.hasData ||
            assignmentSnapshot.data!.docs.isEmpty) {
          return const Center(child: Text("No tasks assigned yet!"));
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('submissions')
              .where('student_id', isEqualTo: user.uid)
              .snapshots(),
          builder: (context, subSnapshot) {
            if (subSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final submittedIds = subSnapshot.data?.docs
                    .map((d) => (d.data()
                        as Map<String, dynamic>)['assignment_id']
                        .toString())
                    .toSet() ??
                {};

            final filteredDocs =
                assignmentSnapshot.data!.docs.where((doc) {
              bool isDone = submittedIds.contains(doc.id);
              return isCompletedPage ? isDone : !isDone;
            }).toList();

            if (filteredDocs.isEmpty) {
              return Center(
                child: Text(
                  isCompletedPage
                      ? "No completed tasks yet!"
                      : "All tasks completed! 🎉",
                ),
              );
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
    );
  }
}