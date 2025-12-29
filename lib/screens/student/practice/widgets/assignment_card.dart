import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'practice_sheet.dart';
import 'detailed_result_view.dart';

class AssignmentCard extends StatelessWidget {
  final DocumentSnapshot assignmentDoc;
  final String studentId;

  const AssignmentCard({super.key, required this.assignmentDoc, required this.studentId});

  @override
  Widget build(BuildContext context) {
    var data = assignmentDoc.data() as Map<String, dynamic>;
    String title = data['title'] ?? 'Untitled';
    int points = data['points'] ?? 10;

    return StreamBuilder<QuerySnapshot>(
      // Listen for the submission of THIS student for THIS assignment
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

        return Card(
          color: isDone ? Colors.grey.shade50 : Colors.white,
          elevation: isDone ? 1 : 4,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
              side: isDone ? BorderSide(color: Colors.green.shade200, width: 2) : BorderSide.none
          ),
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Expanded(
                      child: Text(
                          title,
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              decoration: isDone ? TextDecoration.lineThrough : null,
                              color: isDone ? Colors.grey : Colors.black
                          )
                      )
                  ),
                  if (isDone) const Icon(Icons.check_circle, color: Colors.green),
                ]),
                const SizedBox(height: 10),

                // Content Preview
                Text(
                    data['content'] ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey[600])
                ),
                const SizedBox(height: 15),

                // FOOTER
                Row(
                  children: [
                    const Icon(Icons.monetization_on, size: 16, color: Colors.amber),
                    Text(" $points Pts", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                    const Spacer(),

                    if (!isDone)
                      ElevatedButton.icon(
                        icon: const Icon(Icons.mic), label: const Text("Start"),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
                        onPressed: () => showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.white,
                          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
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
                      )
                    else
                      Row(
                        children: [
                          Text("Score: $score% ", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.visibility, size: 16),
                            label: const Text("Report"),
                            style: OutlinedButton.styleFrom(foregroundColor: Colors.green, padding: const EdgeInsets.symmetric(horizontal: 10)),
                            onPressed: () => _showPreviousResult(context, subData!),
                          ),
                        ],
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

  // ⚠️ UPDATED: Now fetches ALL metrics from Firestore map
  void _showPreviousResult(BuildContext context, Map<String, dynamic> data) {
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
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text("Past Performance", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))
              ]),
              const Divider(),

              // PASS ALL DATA FIELDS HERE
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