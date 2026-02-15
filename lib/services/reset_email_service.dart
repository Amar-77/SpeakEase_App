import 'package:firebase_auth/firebase_auth.dart';

class ResetEmailService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<String?> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return null; // Success (null means no error)
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        return 'No user found for that email.';
      } else if (e.code == 'invalid-email') {
        return 'Please enter a valid email address.';
      } else {
        return 'Error: ${e.message}';
      }
    } catch (e) {
      return 'An unexpected error occurred.';
    }
  }
}