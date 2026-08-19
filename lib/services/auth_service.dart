import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/app_state.dart';
import 'wallet_service.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static User? get currentUser => _auth.currentUser;

  static Future<Map<String, dynamic>> register(String email, String password, {String? name, String? licensePlate}) async {
    try {
      // Add 10 second timeout to prevent long loading
      final UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      ).timeout(const Duration(seconds: 10), onTimeout: () {
        throw FirebaseAuthException(
          code: 'timeout',
          message: 'Connection timeout. Please check your internet.',
        );
      });
      
      // Save user profile to Firestore with timeout
      if (result.user != null && name != null) {
        await _firestore.collection('users').doc(result.user!.uid).set({
          'name': name,
          'licensePlate': licensePlate ?? '',
          'email': email,
          'createdAt': FieldValue.serverTimestamp(),
        }).timeout(const Duration(seconds: 5), onTimeout: () {
          // Continue even if Firestore fails
        });
        
        // Save to AppState
        AppState.customerName = name;
        AppState.licensePlate = licensePlate ?? '';
      }
      
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
        'message': 'Connection failed. Please check internet and try again.',
      };
    }
  }

  static Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      // Add 10 second timeout to prevent long loading
      final UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      ).timeout(const Duration(seconds: 10), onTimeout: () {
        throw FirebaseAuthException(
          code: 'timeout',
          message: 'Connection timeout. Please check your internet.',
        );
      });
      
      // Fetch user profile from Firestore with timeout
      if (result.user != null) {
        try {
          final doc = await _firestore.collection('users').doc(result.user!.uid).get()
            .timeout(const Duration(seconds: 5));
          if (doc.exists) {
            final data = doc.data();
            AppState.customerName = data?['name'] ?? '';
            AppState.licensePlate = data?['licensePlate'] ?? '';
          }
          
          // Load wallet data from Firestore
          await WalletService.loadWalletData();
          
          // Load order history from Firestore
          await WalletService.loadOrders();
        } catch (e) {
          // Continue even if Firestore fetch fails
        }
      }
      
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
        'message': 'Connection failed. Please check internet and try again.',
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
      case 'timeout':
        return 'Connection timeout. Please check internet.';
      case 'network-request-failed':
        return 'Network error. Check your connection.';
      default:
        return 'Authentication failed. Try again.';
    }
  }
}
