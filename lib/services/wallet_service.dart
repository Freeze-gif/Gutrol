import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'app_state.dart';

/// Wallet Service - Manages wallet balance and transactions in Firebase
class WalletService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get current user ID
  static String? get _userId => _auth.currentUser?.uid;

  /// Load wallet data from Firestore
  static Future<void> loadWalletData() async {
    final userId = _userId;
    if (userId == null) return;

    try {
      final doc = await _firestore.collection('wallets').doc(userId).get();
      
      if (doc.exists) {
        final data = doc.data()!;
        AppState.walletBalance = (data['balance'] ?? 0.0).toDouble();
        
        // Load transactions
        final transactions = data['transactions'] as List<dynamic>? ?? [];
        AppState.walletTransactions.clear();
        for (var tx in transactions) {
          AppState.walletTransactions.add(Map<String, dynamic>.from(tx));
        }
      } else {
        // Create new wallet document
        await _createWallet();
      }
    } catch (e) {
      print('[WalletService] Error loading wallet: $e');
    }
  }

  /// Save wallet balance to Firestore
  static Future<void> saveWalletBalance() async {
    final userId = _userId;
    if (userId == null) return;

    try {
      await _firestore.collection('wallets').doc(userId).update({
        'balance': AppState.walletBalance,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('[WalletService] Error saving balance: $e');
    }
  }

  /// Add transaction to Firestore
  static Future<void> addTransaction(Map<String, dynamic> transaction) async {
    final userId = _userId;
    if (userId == null) return;

    try {
      await _firestore.collection('wallets').doc(userId).update({
        'balance': AppState.walletBalance,
        'transactions': FieldValue.arrayUnion([transaction]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('[WalletService] Error adding transaction: $e');
    }
  }

  /// Save order to Firestore history
  static Future<void> saveOrder(Map<String, dynamic> order) async {
    final userId = _userId;
    if (userId == null) return;

    try {
      // Add to user's orders collection
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('orders')
          .add({
        ...order,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('[WalletService] Error saving order: $e');
    }
  }

  /// Update order status in Firestore
  static Future<void> updateOrderStatus(String orderId, String status, double amount) async {
    final userId = _userId;
    if (userId == null) return;

    try {
      // Find and update the most recent pending order
      final ordersQuery = await _firestore
          .collection('users')
          .doc(userId)
          .collection('orders')
          .where('status', isEqualTo: 'Pending')
          .get();

      if (ordersQuery.docs.isNotEmpty) {
        // Find the most recent one locally if multiple exist
        var docToUpdate = ordersQuery.docs.first;
        if (ordersQuery.docs.length > 1) {
          for (var doc in ordersQuery.docs) {
            final docTime = (doc.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
            final currentBestTime = (docToUpdate.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
            if (docTime > currentBestTime) {
              docToUpdate = doc;
            }
          }
        }
        
        // Calculate liters from amount for proper display
        const double pricePerLiter = 3200.0;
        final liters = amount / pricePerLiter;
        
        await docToUpdate.reference.update({
          'status': status,
          'amount': '${liters.toStringAsFixed(2)} Liters / ${amount.toStringAsFixed(0)} MMK',
          'completedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('[WalletService] Error updating order: $e');
    }
  }

  /// Load user orders from Firestore
  static Future<void> loadOrders() async {
    final userId = _userId;
    if (userId == null) return;

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('orders')
          .orderBy('createdAt', descending: true)
          .get();

      AppState.history.clear();
      for (var doc in snapshot.docs) {
        final data = doc.data();
        AppState.history.add({
          'id': doc.id,
          'fuelType': data['fuelType'] ?? 'Petrol 92',
          'mode': data['mode'] ?? 'Manual Filling',
          'amount': data['amount'] ?? '0 MMK',
          'date': (data['createdAt'] as Timestamp?)?.toDate().toString() ?? DateTime.now().toString(),
          'status': data['status'] ?? 'Pending',
        });
      }
    } catch (e) {
      print('[WalletService] Error loading orders: $e');
    }
  }

  /// Delete all order history for the current user
  static Future<void> clearOrderHistory() async {
    final userId = _userId;
    if (userId == null) return;

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('orders')
          .get();

      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      
      AppState.history.clear();
    } catch (e) {
      print('[WalletService] Error clearing order history: $e');
    }
  }

  /// Create new wallet document
  static Future<void> _createWallet() async {
    final userId = _userId;
    if (userId == null) return;

    try {
      await _firestore.collection('wallets').doc(userId).set({
        'userId': userId,
        'balance': 0.0,
        'transactions': [],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('[WalletService] Error creating wallet: $e');
    }
  }

  /// Sync all wallet data to Firestore
  static Future<void> syncToFirebase() async {
    final userId = _userId;
    if (userId == null) return;

    try {
      await _firestore.collection('wallets').doc(userId).set({
        'userId': userId,
        'balance': AppState.walletBalance,
        'transactions': AppState.walletTransactions,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('[WalletService] Error syncing wallet: $e');
    }
  }
}
