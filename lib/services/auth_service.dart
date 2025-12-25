import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // --- SIGN UP ---
  Future<String?> signUpUser({
    required String email,
    required String password,
    required String name,
    required String role,    // 'student' or 'teacher'
    required String classId, // e.g. 'class_6A'
  }) async {
    try {
      // 1. Create Auth Account
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = result.user;

      if (user != null) {
        // 2. Create Firestore Profile
        await _firestore.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'name': name,
          'email': email,
          'role': role,
          'class_id': classId,
          'school_id': 'marian_eng_01', // Hardcoded link to your manual school
          'created_at': FieldValue.serverTimestamp(),
          'speech_coins': 0, // Default for students
        });
      }
      return null; // Success
    } on FirebaseAuthException catch (e) {
      return e.message;
    } catch (e) {
      print(e.toString());
      return e.toString();
    }
  }

  // --- SIGN IN ---
  Future<String?> signInUser({required String email, required String password}) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    }
  }

  // --- LOGOUT ---
  Future<void> signOut() async {
    await _auth.signOut();
  }
}