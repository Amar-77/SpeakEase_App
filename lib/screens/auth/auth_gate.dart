import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Check these imports to ensure they match your folder structure
import 'package:speakease/screens/auth/login_screen.dart';
import 'package:speakease/screens/student/home/student_home.dart';
import 'package:speakease/screens/teacher/home/teacher_home.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      // Stream 1: Listens for Login/Logout
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        // Not logged in? Show Login Screen.
        if (!authSnapshot.hasData) return const LoginScreen();

        User user = authSnapshot.data!;

        // Stream 2: Listens to their Firestore Document instantly
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
          builder: (context, userSnapshot) {

            // While fetching data, show loading
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.blueAccent)));
            }

            // Once the document exists and has data, route them based on role!
            if (userSnapshot.hasData && userSnapshot.data!.exists) {
              var data = userSnapshot.data!.data() as Map<String, dynamic>;
              String role = data['role'] ?? 'student'; // Fallback to student just in case

              return role == 'teacher' ? const TeacherHome() : const StudentHome();
            }

            // If Auth is true, but Firestore doc doesn't exist YET (during signup save),
            // keep showing the loading spinner. Do NOT return the LoginScreen here!
            return const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.purpleAccent)));
          },
        );
      },
    );
  }
}