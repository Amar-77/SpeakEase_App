import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'practice_sheet.dart';
import 'detailed_result_view.dart';

class AssignmentCard extends StatelessWidget {
  final DocumentSnapshot assignmentDoc;
  final String studentId;

  const AssignmentCard({
    super.key,
    required this.assignmentDoc,
    required this.studentId,
  });

  @override
  Widget build(BuildContext context) {
    var data = assignmentDoc.data() as Map<String, dynamic>;
    String title = data['title'] ?? 'Untitled';
    int points = data['points'] ?? 10;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('submissions')
          .where('assignment_id', isEqualTo: assignmentDoc.id)
          .where('student_id', isEqualTo: studentId)
          .snapshots(),
      builder: (context, snapshot) {

        bool isDone = snapshot.hasData && snapshot.data!.docs.isNotEmpty;
        Map<String, dynamic>? subData;
        int score = 0;

        if (isDone) {
          subData = snapshot.data!.docs.first.data() as Map<String, dynamic>;
          score = subData['accuracy_score'] ?? 0;
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
             color: isDone
      ? const Color.fromARGB(255, 107, 201, 109).withOpacity(0.92)
      : const Color(0xFFE0E0E0),
            borderRadius: BorderRadius.circular(20),

            /// 🔥 Optional shadow
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              /// 🔹 TITLE + STATUS
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        decoration
                            : null,
                        color:Colors.black,
                      ),
                    ),
                  ),
                  
                ],
              ),

              const SizedBox(height: 8),

              /// 🔹 DESCRIPTION
              Text(
                data['content'] ?? '',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey.shade700),
              ),

              const SizedBox(height: 16),

              /// 🔹 FOOTER
              Row(
                children: [

                  /// 🪙 COIN
                  Image.asset(
                    'assets/images/speech_coin.png',
                    height: 22,
                  ),

                  const SizedBox(width: 6),

                  Text(
                    "$points pts",
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  const Spacer(),

                  /// 🔥 START BUTTON (IMAGE)
                  if (!isDone)
                    GestureDetector(
                      onTap: () => showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.white,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(
                              top: Radius.circular(20)),
                        ),
                        builder: (ctx) => FractionallySizedBox(
                          heightFactor: 0.9,
                          child: PracticeRecordingSheet(
                            assignmentId: assignmentDoc.id,
                            referenceText: data['content'],
                            basePoints: points,
                            studentId: studentId,
                          ),
                        ),
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2E2E2E),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Image.asset(
                          'assets/images/startmic.png',
                          height: 20,
                        ),
                      ),
                    )

                  /// ✅ COMPLETED UI
                  else
                    Row(
                      children: [
                        Text(
                          "$score%",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color.fromARGB(255, 85, 88, 85),
                          ),
                        ),
                        const SizedBox(width: 10),
                        GestureDetector(
                          onTap: () =>
                              _showPreviousResult(context, subData!),
                          child: const Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  /// 🔍 VIEW PREVIOUS RESULT
  void _showPreviousResult(
      BuildContext context, Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            children: [
              Row(
                  mainAxisAlignment:
                  MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Past Performance",
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context))
                  ]),
              const Divider(),

              DetailedResultView(
                overallScore:
                (data['accuracy_score'] ?? 0).toDouble(),
                fluency:
                (data['fluency_score'] ?? 0).toDouble(),
                pronunciation:
                (data['pronunciation_score'] ?? 0)
                    .toDouble(),
                clarity:
                (data['clarity_score'] ?? 0).toDouble(),
                accuracy:
                (data['transcription_accuracy'] ?? 0)
                    .toDouble(),
                wpm: (data['wpm'] ?? 0).toDouble(),
                ageGroup: data['detected_age'] ?? "Unknown",
                wordAnalysis: data['word_analysis'] ?? [],
                userTranscription:
                data['full_transcription'] ?? "",
              ),
            ],
          ),
        ),
      ),
    );
  }
}