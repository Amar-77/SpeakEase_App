import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../assignments/create_assignment_screen.dart';
import '../assignments/teacher_history_screen.dart';
import '../students/student_list_screen.dart'; // Make sure to import this

class TeacherHome extends StatelessWidget {
  const TeacherHome({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Teacher Dashboard"),
        backgroundColor: Colors.teal,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async => await FirebaseAuth.instance.signOut(),
          )
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          var data = snapshot.data!.data() as Map<String, dynamic>;

          return Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.school, size: 100, color: Colors.teal),
                  const SizedBox(height: 20),
                  Text("Welcome, ${data['name']}!", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  Text("Class ID: ${data['class_id'] ?? 'N/A'}", style: const TextStyle(color: Colors.grey, fontSize: 16)),
                  const SizedBox(height: 40),

                  // 1. Create Button
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateAssignmentScreen()));
                    },
                    icon: const Icon(Icons.add_circle, size: 28),
                    label: const Text("Create New Assignment", style: TextStyle(fontSize: 18)),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 2. History Button
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const TeacherHistoryScreen()));
                    },
                    icon: const Icon(Icons.history, color: Colors.teal),
                    label: const Text("View Sent Assignments", style: TextStyle(color: Colors.teal)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                      side: const BorderSide(color: Colors.teal),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 3. Student List Button (The new feature)
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => StudentListScreen(classId: data['class_id'] ?? 'class_6A')
                          )
                      );
                    },
                    icon: const Icon(Icons.people, color: Colors.teal),
                    label: const Text("My Students & Progress", style: TextStyle(color: Colors.teal)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                      side: const BorderSide(color: Colors.teal),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}