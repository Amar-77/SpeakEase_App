import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'create_assignment_screen.dart';

class TeacherHistoryScreen extends StatelessWidget {
  const TeacherHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),

      /// ✅ APP BAR
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Sent Assignments",
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      /// ✅ BODY (LOGIC UNCHANGED)
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('assignments')
            .where('teacher_id', isEqualTo: user.uid)
            .orderBy('created_at', descending: true)
            .snapshots(),
        builder: (context, snapshot) {

          /// 1. Loading
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          /// 2. Error
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text(
                  "Error: ${snapshot.error}",
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          /// 3. Empty
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history_toggle_off,
                      size: 60, color: Colors.grey),
                  SizedBox(height: 10),
                  Text("No assignments sent yet."),
                ],
              ),
            );
          }

          /// 4. LIST
          return ListView.builder(
            padding: const EdgeInsets.all(15),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var doc = snapshot.data!.docs[index];
              var data = doc.data() as Map<String, dynamic>;

              String difficulty = data['difficulty'] ?? 'Easy';

              /// 🎨 Difficulty colors
              Color badgeColor = difficulty == 'Hard'
                  ? Colors.red.shade100
                  : (difficulty == 'Medium'
                      ? Colors.orange.shade100
                      : Colors.green.shade100);

              Color textColor = difficulty == 'Hard'
                  ? Colors.red.shade800
                  : (difficulty == 'Medium'
                      ? Colors.deepOrange
                      : Colors.green.shade800);

              return Container(
  height: 140,
  margin: const EdgeInsets.only(bottom: 15),
  padding: const EdgeInsets.all(14),
  decoration: BoxDecoration(
    color: const Color(0xFFEAEAEA),
    borderRadius: BorderRadius.circular(20),
  ),

  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [

      /// 🔹 TITLE (STRICT LIMIT)
      Text(
        data['title'] ?? 'Untitled',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),

      const SizedBox(height: 4),

      /// 🔹 CONTENT (STRICT CONTROL)
      Expanded(
        child: Text(
          data['content'] ?? '',
          maxLines: 3, // 👈 VERY IMPORTANT (was 3 → causing overflow)
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 12.5,
          ),
        ),
      ),

      /// 🔹 BOTTOM ROW (FIXED HEIGHT SAFE)
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [

          /// DIFFICULTY
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: badgeColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              difficulty,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),

          /// EDIT BUTTON
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      CreateAssignmentScreen(
                    assignmentToEdit: doc,
                  ),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(15), // 👈 smaller
              decoration: BoxDecoration(
                color: const Color(0xFF2E2E2E),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.edit,
                color: Colors.white,
                size: 17,
              ),
            ),
          ),
        ],
      ),
    ],
  ),
);
            },
          );
        },
      ),
    );
  }
}