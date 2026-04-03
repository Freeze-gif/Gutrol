import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static User? get currentUser => _auth.currentUser;

  static Future<Map<String, dynamic>> register(String email, String password) async {
    try {
      final UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return {
        'success': true,
        'user': result.user,
        'message': 'Registration successful',
      };
    } on FirebaseAuthException catch (e) {
      return {
        'success': false,
        'message': _getErrorMessage(e.code),
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'An unexpected error occurred',
      };
    }
  }

  static Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return {
        'success': true,
        'user': result.user,
        'message': 'Login successful',
      };
    } on FirebaseAuthException catch (e) {
      return {
        'success': false,
        'message': _getErrorMessage(e.code),
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'An unexpected error occurred',
      };
    }
  }

  static Future<Map<String, dynamic>> logout() async {
    try {
      await _auth.signOut();
      return {
        'success': true,
        'message': 'Logout successful',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to logout',
      };
    }
  }

  static String _getErrorMessage(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'Email is already registered';
      case 'invalid-email':
        return 'Invalid email address';
      case 'weak-password':
        return 'Password should be at least 6 characters';
      case 'user-not-found':
        return 'No user found with this email';
      case 'wrong-password':
        return 'Incorrect password';
      case 'user-disabled':
        return 'This account has been disabled';
      default:
        return 'Authentication failed';
    }
  }
}
