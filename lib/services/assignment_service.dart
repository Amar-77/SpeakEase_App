import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AssignmentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // --- 1. CREATE ASSIGNMENT ---
  Future<String?> createAssignment({
    required String title,
    required String content,
    required String classId,
    required String difficulty, // 'Easy', 'Medium', 'Hard'
    required String category,   // 'Story', etc.
  }) async {
    try {
      User? user = _auth.currentUser;
      if (user == null) return "User not logged in";

      // Calculate points automatically
      int points = _calculatePoints(difficulty);

      await _firestore.collection('assignments').add({
        'title': title,
        'content': content,
        'class_id': classId,
        'teacher_id': user.uid,
        'difficulty': difficulty,
        'category': category,
        'points': points,
        'created_at': FieldValue.serverTimestamp(),
      });

      return null; // Success
    } catch (e) {
      return e.toString();
    }
  }

  // --- 2. UPDATE ASSIGNMENT (The new part) ---
  Future<String?> updateAssignment({
    required String docId, // We need to know WHICH document to update
    required String title,
    required String content,
    required String difficulty,
    required String category,
  }) async {
    try {
      // Recalculate points in case difficulty changed (e.g. Easy -> Hard)
      int points = _calculatePoints(difficulty);

      await _firestore.collection('assignments').doc(docId).update({
        'title': title,
        'content': content,
        'difficulty': difficulty,
        'category': category,
        'points': points,
        // We add this field so we know it was edited
        'updated_at': FieldValue.serverTimestamp(),
      });

      return null; // Success
    } catch (e) {
      return e.toString();
    }
  }

  // --- HELPER: Calculate Points ---
  int _calculatePoints(String difficulty) {
    if (difficulty == 'Medium') return 5;
    if (difficulty == 'Hard') return 10;
    return 3; // Default for Easy
  }
}