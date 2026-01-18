import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  Future<String?> signUpUser({
    required String email,
    required String password,
    required String name,
    required String role,
    required String classId,
  }) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
          email: email, password: password);
      User? user = result.user;

      DateTime oneHourAgo = DateTime.now().subtract(const Duration(hours: 1));

      if (user != null) {
        await _firestore.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'name': name,
          'email': email,
          'role': role,
          'class_id': classId,
          'created_at': FieldValue.serverTimestamp(),
          'last_notification_check': Timestamp.fromDate(oneHourAgo),
          'hidden_notifications': [],
        });

        // AUTO-SUBSCRIBE STUDENT TO CLASS TOPIC
        if (role == 'student') {
          await _fcm.subscribeToTopic(classId);
        }
      }
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> signInUser({required String email, required String password}) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
          email: email, password: password);

      // RE-SYNC TOPIC ON LOGIN (In case they switched phones)
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(result.user!.uid).get();
      if (userDoc.exists && userDoc['role'] == 'student') {
        await _fcm.subscribeToTopic(userDoc['class_id']);
      }
      return null;
    } catch (e) {
      return e.toString();
    }
  }
}