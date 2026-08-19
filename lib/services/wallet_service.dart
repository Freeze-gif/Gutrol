import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'app_state.dart';

/// Wallet Service - Manages wallet balance and transactions in Firebase.
///
/// Firestore is the source of truth for the balance. Every balance change goes
/// through [applyTransaction], which reads and writes the balance inside a
/// Firestore transaction, so the stored balance can never be clobbered by a
/// stale local value.
class WalletService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Most recent failure, so callers can tell the user instead of silently
  /// showing a balance that was never saved.
  static String? lastError;

  /// Keep the embedded transaction list well under the 1 MB document limit.
  static const int _maxStoredTransactions = 100;

  /// Get current user ID
  static String? get _userId => _auth.currentUser?.uid;

  static DocumentReference<Map<String, dynamic>>? get _walletRef {
    final userId = _userId;
    if (userId == null) return null;
    return _firestore.collection('wallets').doc(userId);
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? 0.0;
  }

  static void _fail(String context, Object error) {
    lastError = '$context: $error';
    debugPrint('[WalletService] $lastError');
  }

  /// Load wallet data from Firestore. Returns false when the read failed, so
  /// callers can avoid presenting a stale/zero balance as if it were real.
  static Future<bool> loadWalletData() async {
    final ref = _walletRef;
    if (ref == null) {
      lastError = 'Not signed in';
      return false;
    }

    try {
      final doc = await ref.get();

      if (doc.exists) {
        final data = doc.data() ?? <String, dynamic>{};
        AppState.walletBalance = _toDouble(data['balance']);

        // Stored newest-first; keep that order for display.
        final transactions = data['transactions'] as List<dynamic>? ?? [];
        AppState.walletTransactions
          ..clear()
          ..addAll(transactions.map((tx) => Map<String, dynamic>.from(tx as Map)));
      } else {
        AppState.walletBalance = 0.0;
        AppState.walletTransactions.clear();
        await ensureWallet();
      }
      lastError = null;
      return true;
    } catch (e) {
      _fail('Error loading wallet', e);
      return false;
    }
  }

  /// Create the wallet document if it does not exist yet. Safe to call any
  /// number of times - an existing balance is never overwritten.
  static Future<bool> ensureWallet() async {
    final ref = _walletRef;
    if (ref == null) {
      lastError = 'Not signed in';
      return false;
    }

    try {
      await _firestore.runTransaction((txn) async {
        final snap = await txn.get(ref);
        if (snap.exists) return;
        txn.set(ref, {
          'userId': _userId,
          'balance': 0.0,
          'transactions': <Map<String, dynamic>>[],
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
      lastError = null;
      return true;
    } catch (e) {
      _fail('Error creating wallet', e);
      return false;
    }
  }

  /// Apply a balance change and record the transaction atomically.
  ///
  /// [delta] is added to the stored balance (positive for a top-up, negative
  /// for a purchase). On success [AppState.walletBalance] is updated to the
  /// authoritative stored value and the transaction is prepended locally.
  /// On failure nothing is changed locally, so the UI never shows money that
  /// was not actually saved.
  static Future<bool> applyTransaction(
    Map<String, dynamic> transaction,
    double delta,
  ) async {
    final ref = _walletRef;
    if (ref == null) {
      lastError = 'Not signed in';
      return false;
    }

    try {
      final newBalance = await _firestore.runTransaction<double>((txn) async {
        final snap = await txn.get(ref);
        final data = snap.data() ?? <String, dynamic>{};
        final current = _toDouble(data['balance']);
        final updated = current + delta;

        final stored = (data['transactions'] as List<dynamic>? ?? [])
            .map((tx) => Map<String, dynamic>.from(tx as Map))
            .toList();
        stored.insert(0, transaction);
        if (stored.length > _maxStoredTransactions) {
          stored.removeRange(_maxStoredTransactions, stored.length);
        }

        txn.set(ref, {
          'userId': _userId,
          'balance': updated,
          'transactions': stored,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        return updated;
      });

      AppState.walletBalance = newBalance;
      AppState.addWalletTransaction(transaction);
      lastError = null;
      return true;
    } catch (e) {
      _fail('Error applying transaction', e);
      return false;
    }
  }

  /// Persist the current in-memory balance. Uses set/merge so it also works
  /// when the wallet document does not exist yet.
  static Future<bool> saveWalletBalance() async {
    final ref = _walletRef;
    if (ref == null) {
      lastError = 'Not signed in';
      return false;
    }

    try {
      await ref.set({
        'userId': _userId,
        'balance': AppState.walletBalance,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      lastError = null;
      return true;
    } catch (e) {
      _fail('Error saving balance', e);
      return false;
    }
  }

  /// Save order to Firestore history. Returns the new document id, or null on
  /// failure.
  static Future<String?> saveOrder(Map<String, dynamic> order) async {
    final userId = _userId;
    if (userId == null) {
      lastError = 'Not signed in';
      return null;
    }

    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('orders')
          .add({
        ...order,
        'createdAt': FieldValue.serverTimestamp(),
      });
      lastError = null;
      return doc.id;
    } catch (e) {
      _fail('Error saving order', e);
      return null;
    }
  }

  /// Update an order's status in Firestore. When [orderId] is empty the most
  /// recent pending order is used.
  static Future<bool> updateOrderStatus(
    String orderId,
    String status,
    double amount,
  ) async {
    final userId = _userId;
    if (userId == null) {
      lastError = 'Not signed in';
      return false;
    }

    try {
      final orders =
          _firestore.collection('users').doc(userId).collection('orders');

      DocumentReference<Map<String, dynamic>>? target;
      if (orderId.isNotEmpty) {
        target = orders.doc(orderId);
      } else {
        final pending = await orders.where('status', isEqualTo: 'Pending').get();
        if (pending.docs.isEmpty) {
          lastError = 'No pending order to update';
          return false;
        }

        // Pick the most recent one. A just-written doc has a null local
        // createdAt, so treat null as "newest" rather than oldest.
        var best = pending.docs.first;
        int timeOf(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
          final ts = doc.data()['createdAt'] as Timestamp?;
          return ts?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch;
        }

        for (final doc in pending.docs) {
          if (timeOf(doc) > timeOf(best)) best = doc;
        }
        target = best.reference;
      }

      // Calculate liters from amount for proper display
      const double pricePerLiter = 3200.0;
      final liters = amount / pricePerLiter;

      await target.update({
        'status': status,
        'amount':
            '${liters.toStringAsFixed(2)} Liters / ${amount.toStringAsFixed(0)} MMK',
        'completedAt': FieldValue.serverTimestamp(),
      });
      lastError = null;
      return true;
    } catch (e) {
      _fail('Error updating order', e);
      return false;
    }
  }

  /// Load user orders from Firestore. Returns false when the read failed, so
  /// callers can distinguish "no orders yet" from "could not reach Firestore".
  static Future<bool> loadOrders() async {
    final userId = _userId;
    if (userId == null) {
      lastError = 'Not signed in';
      return false;
    }

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('orders')
          .orderBy('createdAt', descending: true)
          .get();

      final loaded = <Map<String, dynamic>>[];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        loaded.add({
          'id': doc.id,
          'fuelType': data['fuelType'] ?? 'Petrol 92',
          'mode': data['mode'] ?? 'Manual Filling',
          'amount': data['amount'] ?? '0 MMK',
          'date': (data['createdAt'] as Timestamp?)?.toDate().toString() ??
              DateTime.now().toString(),
          'status': data['status'] ?? 'Pending',
        });
      }

      AppState.history
        ..clear()
        ..addAll(loaded);
      lastError = null;
      return true;
    } catch (e) {
      _fail('Error loading orders', e);
      return false;
    }
  }

  /// Delete all order history for the current user
  static Future<bool> clearOrderHistory() async {
    final userId = _userId;
    if (userId == null) {
      lastError = 'Not signed in';
      return false;
    }

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('orders')
          .get();

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      AppState.history.clear();
      lastError = null;
      return true;
    } catch (e) {
      _fail('Error clearing order history', e);
      return false;
    }
  }

  /// Sync all in-memory wallet data to Firestore.
  static Future<bool> syncToFirebase() async {
    final ref = _walletRef;
    if (ref == null) {
      lastError = 'Not signed in';
      return false;
    }

    try {
      await ref.set({
        'userId': _userId,
        'balance': AppState.walletBalance,
        'transactions': AppState.walletTransactions,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      lastError = null;
      return true;
    } catch (e) {
      _fail('Error syncing wallet', e);
      return false;
    }
  }
}
