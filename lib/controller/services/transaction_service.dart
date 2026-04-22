import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

import 'package:money_tracking_app/model/transaction_model.dart';
import 'budget_service.dart';
import 'notification_service.dart';

class TransactionService {
  TransactionService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    NotificationService? notificationService,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _notificationService =
           notificationService ?? NotificationService.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final NotificationService _notificationService;
  final BudgetService _budgetService = BudgetService();
  static const Duration _operationTimeout = Duration(seconds: 8);

  CollectionReference<Map<String, dynamic>> get _transactions =>
      _firestore.collection('transactions');

  CollectionReference<Map<String, dynamic>> _userTransactions(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('transactions');
  }

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  Future<String> createTransaction({
    String? id,
    required String userId,
    String? userName,
    required double amount,
    required String category,
    required String description,
    required DateTime date,
    required String type,
    String status = 'Pending',
    String? rejectionReason,
  }) async {
    if (userId.trim().isEmpty) {
      throw StateError('User id cannot be empty.');
    }

    final currentUser = _auth.currentUser;

    final autoApproveEnabled = await _isAutoApproveEnabled();
    final shouldAutoApprove =
        autoApproveEnabled &&
        amount < 1000 &&
        _normalizeStatus(status) == 'Pending';
    final resolvedUserName = await _resolveUserName(
      userId: userId,
      fallbackName: userName,
      currentUser: currentUser,
    );
    final resolvedUserEmail = await _resolveUserEmail(
      userId: userId,
      currentUser: currentUser,
    );
    final now = DateTime.now();
    final docRef = id == null || id.isEmpty
        ? _transactions.doc()
        : _transactions.doc(id);

    final transaction = TransactionModel(
      id: docRef.id,
      userId: userId,
      userName: resolvedUserName,
      userEmail: resolvedUserEmail,
      amount: amount,
      category: category,
      description: description,
      date: date,
      status: _normalizeStatus(shouldAutoApprove ? 'Approved' : status),
      type: type.toLowerCase(),
      rejectionReason: rejectionReason,
      createdAt: now,
      updatedAt: now,
    );

    final transactionData = transaction.toMap();
    await docRef.set(transactionData);
    await _userTransactions(
      userId,
    ).doc(docRef.id).set(transactionData, SetOptions(merge: true));

    if (transaction.isApproved) {
      final delta = transaction.type == 'income'
          ? transaction.amount
          : -transaction.amount;
      await _users.doc(userId).set({
        'balance': FieldValue.increment(delta),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    if (transaction.type == 'expense' && transaction.isApproved) {
      try {
        await _budgetService.checkBudgetAfterTransaction(
          uid: userId,
          transactionDate: date,
          category: category,
          transactionAmount: amount,
          transactionType: type,
        );
      } catch (e) {
        print('âš ï¸ Budget alert check failed: $e');
      }
    }

    if (shouldAutoApprove) {
      unawaited(
        _notificationService.sendTransactionUpdateNotification(
          userId: userId,
          title: 'Transaction auto-approved',
          message:
              'Your transaction of â‚¹${amount.toStringAsFixed(0)} was auto-approved by admin settings.',
          transactionId: docRef.id,
          status: 'Approved',
        ),
      );
    }

    return docRef.id;
  }

  Future<bool> _isAutoApproveEnabled() async {
    final settings = await _firestore
        .collection('system_settings')
        .doc('global')
        .get();
    return settings.data()?['autoApprove'] == true;
  }

  Stream<List<TransactionModel>> getTransactionsByStatus(String status) {
    final normalizedFilter = status.trim().toLowerCase();
    Query<Map<String, dynamic>> query = _transactions;

    if (normalizedFilter.isNotEmpty && normalizedFilter != 'all') {
      query = query.where(
        'status',
        isEqualTo: _normalizeStatus(normalizedFilter),
      );
    }

    return query.snapshots().map((snapshot) {
      final transactions = snapshot.docs
          .map((doc) => TransactionModel.fromDoc(doc))
          .toList();
      transactions.sort((a, b) => b.date.compareTo(a.date));
      return transactions;
    });
  }

  Stream<List<TransactionModel>> getUserTransactions(String userId) {
    return _userTransactions(userId).snapshots().map((snapshot) {
      final transactions = snapshot.docs
          .map((doc) => TransactionModel.fromDoc(doc))
          .toList();
      transactions.sort((a, b) => b.date.compareTo(a.date));
      return transactions;
    });
  }

  Future<void> approveTransaction(String transactionId) async {
    await _ensureAdmin();

    final normalizedTransactionId = transactionId.trim();
    if (normalizedTransactionId.isEmpty) {
      throw StateError('Transaction id cannot be empty.');
    }

    final transactionRef = _transactions.doc(normalizedTransactionId);
    TransactionModel? approvedTransaction;

    await _firestore.runTransaction((transaction) async {
      final transactionSnap = await transaction.get(transactionRef);
      if (!transactionSnap.exists) {
        throw StateError('Transaction not found.');
      }

      final currentTransaction = TransactionModel.fromDoc(transactionSnap);
      if (currentTransaction.isApproved) {
        approvedTransaction = currentTransaction;
        return;
      }
      if (currentTransaction.isRejected) {
        throw StateError('Rejected transactions cannot be approved.');
      }

      final userId = currentTransaction.userId.trim();
      final userRef = userId.isEmpty ? null : _users.doc(userId);
      final currentBalance = userRef == null
          ? null
          : _readBalance((await transaction.get(userRef)).data());

      final updatedTransaction = currentTransaction.copyWith(
        status: 'Approved',
        rejectionReason: null,
        updatedAt: DateTime.now(),
      );

      transaction.set(
        transactionRef,
        updatedTransaction.toMap(),
        SetOptions(merge: true),
      );

      if (userId.isNotEmpty) {
        transaction.set(
          _userTransactions(userId).doc(updatedTransaction.id),
          updatedTransaction.toMap(),
          SetOptions(merge: true),
        );
      }

      if (userRef != null && currentBalance != null) {
        transaction.set(userRef, {
          'balance':
              currentBalance +
              (currentTransaction.type == 'income'
                  ? currentTransaction.amount
                  : -currentTransaction.amount),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      approvedTransaction = updatedTransaction;
    });

    if (approvedTransaction != null &&
        approvedTransaction!.userId.trim().isNotEmpty) {
      if (approvedTransaction!.type == 'expense') {
        unawaited(
          _budgetService.checkBudgetAfterTransaction(
            uid: approvedTransaction!.userId,
            transactionDate: approvedTransaction!.date,
            category: approvedTransaction!.category,
            transactionAmount: approvedTransaction!.amount,
            transactionType: approvedTransaction!.type,
          ),
        );
      }

      print(
        'ðŸ“¢ Sending approval notification for transaction: ${approvedTransaction!.id}',
      );
      unawaited(
        _notificationService.sendTransactionUpdateNotification(
          userId: approvedTransaction!.userId,
          title: 'Transaction approved',
          message:
              'Your transaction of â‚¹${approvedTransaction!.amount.toStringAsFixed(0)} has been approved.',
          transactionId: approvedTransaction!.id,
          status: 'Approved',
        ),
      );
    }
  }

  Future<void> rejectTransaction(String transactionId, String reason) async {
    await _ensureAdmin();

    final normalizedTransactionId = transactionId.trim();
    if (normalizedTransactionId.isEmpty) {
      throw StateError('Transaction id cannot be empty.');
    }

    final normalizedReason = reason.trim();
    if (normalizedReason.isEmpty) {
      throw StateError('Rejection reason is required.');
    }

    final transactionRef = _transactions.doc(normalizedTransactionId);
    final transactionSnap = await transactionRef.get().timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw TimeoutException('Loading transaction timed out.'),
    );

    if (!transactionSnap.exists) {
      throw StateError('Transaction not found.');
    }

    final currentTransaction = TransactionModel.fromDoc(transactionSnap);
    if (currentTransaction.isRejected) {
      return;
    }
    if (currentTransaction.isApproved) {
      throw StateError('Approved transactions cannot be rejected.');
    }

    final rejectedTransaction = currentTransaction.copyWith(
      status: 'Rejected',
      rejectionReason: normalizedReason,
      updatedAt: DateTime.now(),
    );

    await transactionRef
        .set(rejectedTransaction.toMap(), SetOptions(merge: true))
        .timeout(
          const Duration(seconds: 10),
          onTimeout: () =>
              throw TimeoutException('Saving rejection update timed out.'),
        );

    final rejectedUserId = rejectedTransaction.userId.trim();
    if (rejectedUserId.isNotEmpty) {
      await _userTransactions(rejectedUserId)
          .doc(rejectedTransaction.id)
          .set(rejectedTransaction.toMap(), SetOptions(merge: true));
    }

    if (rejectedTransaction.userId.trim().isNotEmpty) {
      print(
        'ðŸ“¢ Sending rejection notification for transaction: ${rejectedTransaction.id}',
      );
      unawaited(
        _notificationService.sendTransactionUpdateNotification(
          userId: rejectedTransaction.userId,
          title: 'Transaction rejected',
          message: 'Your transaction was rejected. Reason: $normalizedReason',
          transactionId: rejectedTransaction.id,
          status: 'Rejected',
          rejectionReason: normalizedReason,
        ),
      );
    }
  }

  Future<void> updateUserBalance(String userId, double amount) async {
    if (userId.trim().isEmpty) {
      throw StateError('User id cannot be empty.');
    }

    await _firestore.runTransaction((transaction) async {
      await _updateUserBalanceInTransaction(
        transaction,
        userId: userId,
        amount: amount,
      );
    });
  }

  Future<void> _updateUserBalanceInTransaction(
    Transaction transaction, {
    required String userId,
    required double amount,
  }) async {
    if (userId.trim().isEmpty) {
      throw StateError('User id cannot be empty.');
    }

    final userRef = _users.doc(userId);
    final userSnap = await transaction.get(userRef);
    final currentBalance = _readBalance(userSnap.data());

    transaction.set(userRef, {
      'balance': currentBalance + amount,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<String> _resolveUserName({
    required String userId,
    String? fallbackName,
    User? currentUser,
  }) async {
    if (fallbackName != null && fallbackName.trim().isNotEmpty) {
      return fallbackName.trim();
    }

    final userDoc = await _users.doc(userId).get();
    final name = (userDoc.data()?['name'] ?? '').toString().trim();
    if (name.isNotEmpty) {
      return name;
    }

    final displayName = currentUser?.displayName?.trim() ?? '';
    if (displayName.isNotEmpty) {
      return displayName;
    }

    final email = currentUser?.email?.trim() ?? '';
    if (email.isNotEmpty) {
      return email;
    }

    return 'Unknown User';
  }

  Future<String?> _resolveUserEmail({
    required String userId,
    User? currentUser,
  }) async {
    final userDoc = await _users.doc(userId).get();
    final email = (userDoc.data()?['email'] ?? '').toString().trim();
    if (email.isNotEmpty) {
      return email;
    }

    final authEmail = currentUser?.email?.trim() ?? '';
    return authEmail.isEmpty ? null : authEmail;
  }

  Future<void> _ensureAdmin() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw StateError('You must be signed in to perform this action.');
    }

    final data = await _resolveCurrentUserProfile(currentUser).timeout(
      _operationTimeout,
      onTimeout: () => throw TimeoutException('Admin verification timed out.'),
    );
    final role = (data['role'] ?? '').toString().trim().toLowerCase();
    final isAdminFlag = data['isAdmin'] == true;
    final isAdminRole = role == 'admin' || role == 'superadmin';

    if (!isAdminFlag && !isAdminRole) {
      throw StateError(
        'Admin privileges are required. Current role: ${role.isEmpty ? 'unknown' : role}.',
      );
    }
  }

  Future<Map<String, dynamic>> _resolveCurrentUserProfile(
    User currentUser,
  ) async {
    final primaryDoc = await _users
        .doc(currentUser.uid)
        .get()
        .timeout(_operationTimeout);
    final primaryData = primaryDoc.data();

    if (primaryData != null && _hasAdminMarkers(primaryData)) {
      return primaryData;
    }

    final email = (currentUser.email ?? '').trim();
    if (email.isNotEmpty) {
      final byEmail = await _users
          .where('email', isEqualTo: email)
          .limit(1)
          .get()
          .timeout(_operationTimeout);

      if (byEmail.docs.isNotEmpty) {
        final data = byEmail.docs.first.data();

        // Keep future checks consistent by ensuring uid doc carries admin markers.
        if (_hasAdminMarkers(data)) {
          await _users
              .doc(currentUser.uid)
              .set({
                'role': data['role'],
                'isAdmin': data['isAdmin'] == true,
                'email': email,
                'updatedAt': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true))
              .timeout(_operationTimeout);
        }

        return data;
      }
    }

    return primaryData ?? {};
  }

  bool _hasAdminMarkers(Map<String, dynamic> data) {
    final role = (data['role'] ?? '').toString().trim().toLowerCase();
    return data['isAdmin'] == true || role == 'admin' || role == 'superadmin';
  }

  double _readBalance(Map<String, dynamic>? data) {
    final raw = data?['balance'];
    if (raw is num) return raw.toDouble();
    return double.tryParse(raw?.toString() ?? '') ?? 0;
  }

  String _normalizeStatus(String status) {
    final normalized = status.trim().toLowerCase();
    switch (normalized) {
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      default:
        return 'Pending';
    }
  }
}
