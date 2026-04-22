import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:money_tracking_app/model/money_transaction.dart';
import 'package:money_tracking_app/model/user_model.dart';
import 'transaction_service.dart';
import 'package:money_tracking_app/view/utils/currency_utils.dart';

class FirestoreService {
  static const double incomeMaxLimit = 30000;

  final _db = FirebaseFirestore.instance;
  final _transactionService = TransactionService();
  final DocumentReference<Map<String, dynamic>> _systemSettingsRef =
      FirebaseFirestore.instance.collection('system_settings').doc('global');

  static const Map<String, dynamic> systemSettingsDefaults = {
    'maintenanceMode': false,
    'emailNotifications': true,
    'pushNotifications': true,
    'twoFactorAuth': false,
    'autoApprove': false,
    'darkModeForced': false,
    'sessionTimeout': '30 min',
    'maxTransactionLimit': 'â‚¹5,000',
    'defaultCurrency': 'USD',
    'appVersion': '1.0.0',
    'buildNumber': '42',
    'environment': 'Production',
  };

  // â”€â”€ TRANSACTIONS â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  CollectionReference<Map<String, dynamic>> _userTransactionsRef(String uid) {
    return _db.collection('users').doc(uid).collection('transactions');
  }

  Stream<List<MoneyTransaction>> streamTransactions({String? userId}) {
    Query<Map<String, dynamic>> query;

    if (userId != null && userId.trim().isNotEmpty) {
      query = _userTransactionsRef(
        userId,
      ).orderBy('createdAt', descending: true);
    } else {
      query = _db
          .collection('transactions')
          .orderBy('createdAt', descending: true);
    }

    return query.snapshots().map((snap) {
      final transactions = snap.docs
          .map((d) => MoneyTransaction.fromDoc(d))
          .toList();

      transactions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return transactions;
    });
  }

  Future<List<MoneyTransaction>> fetchTransactionsOnce({String? userId}) async {
    Query<Map<String, dynamic>> query;

    if (userId != null && userId.trim().isNotEmpty) {
      query = _userTransactionsRef(
        userId,
      ).orderBy('createdAt', descending: true);
    } else {
      query = _db.collection('transactions');
    }

    final snap = await query.get();
    final transactions = snap.docs.map(MoneyTransaction.fromDoc).toList();
    transactions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return transactions;
  }

  Future<void> addTransaction({
    required String userId,
    required double amount,
    required String type,
    required String category,
    required String note,
    DateTime? date,
  }) async {
    final normalizedType = type.trim().toLowerCase();
    final settings = await getSystemSettings();
    final maxLimit = parseMaxTransactionLimit(settings['maxTransactionLimit']);
    final resolvedLimit = normalizedType == 'income'
        ? incomeMaxLimit
        : maxLimit.clamp(0, 5000).toDouble();

    if (amount > resolvedLimit) {
      final label = normalizedType == 'income' ? 'Income' : 'Transaction';
      throw StateError(
        '$label amount cannot exceed ${formatTransactionLimit(resolvedLimit)}.',
      );
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    await _transactionService.createTransaction(
      userId: userId,
      userName: currentUser?.displayName ?? currentUser?.email,
      amount: amount,
      category: category,
      description: note,
      date: date ?? DateTime.now(),
      type: normalizedType,
      status: 'Pending',
    );
  }

  Future<void> deleteTransaction(String id) async {
    if (id.trim().isEmpty) {
      throw StateError('Transaction id cannot be empty.');
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      await _userTransactionsRef(currentUser.uid).doc(id).delete();
    }

    await _db.collection('transactions').doc(id).delete();
  }

  // â”€â”€ USER MANAGEMENT â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  /// Stream all users with real-time updates
  Stream<List<UserModel>> streamAllUsers() {
    return _db
        .collection('users')
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => UserModel.fromDoc(d)).toList()
                ..sort((a, b) => b.joinedDate.compareTo(a.joinedDate)),
        );
  }

  /// Get a single user by UID
  Future<UserModel?> getUserById(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (doc.exists) {
        return UserModel.fromDoc(doc);
      }
      return null;
    } catch (e) {
      print('Error fetching user: $e');
      return null;
    }
  }

  /// Returns true when the user has admin privileges.
  Future<bool> isUserAdmin(String uid, {String? email}) async {
    try {
      final userDoc = await _db.collection('users').doc(uid).get();
      final data = userDoc.data();

      if (_hasAdminMarkers(data)) {
        return true;
      }

      final normalizedEmail = (email ?? '').trim();
      if (normalizedEmail.isNotEmpty) {
        final byEmail = await _db
            .collection('users')
            .where('email', isEqualTo: normalizedEmail)
            .limit(1)
            .get();

        if (byEmail.docs.isNotEmpty &&
            _hasAdminMarkers(byEmail.docs.first.data())) {
          return true;
        }
      }

      return false;
    } catch (e) {
      print('Error checking admin role: $e');
      return false;
    }
  }

  Future<bool> isCurrentUserAdmin() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return false;

    return isUserAdmin(currentUser.uid, email: currentUser.email);
  }

  /// Create or update a user
  Future<void> setUser(UserModel user) async {
    await _db.collection('users').doc(user.uid).set(user.toMap());
  }

  /// Update user role
  Future<void> updateUserRole(String uid, String newRole) async {
    await _db.collection('users').doc(uid).update({'role': newRole});
  }

  /// Toggle user active status
  Future<void> toggleUserStatus(String uid, bool active) async {
    await _db.collection('users').doc(uid).update({'active': active});
  }

  /// Delete a user
  Future<void> deleteUser(String uid) async {
    await _db.collection('users').doc(uid).delete();
  }

  /// Get transaction count for a user
  Future<int> getUserTransactionCount(String uid) async {
    try {
      final querySnapshot = await _userTransactionsRef(uid).get();
      return querySnapshot.docs.length;
    } catch (e) {
      print('Error getting transaction count: $e');
      return 0;
    }
  }

  /// Update user's transaction count
  Future<void> updateUserTransactionCount(String uid, int count) async {
    await _db.collection('users').doc(uid).update({'transactionCount': count});
  }

  bool _hasAdminMarkers(Map<String, dynamic>? data) {
    if (data == null) return false;
    final role = (data['role'] ?? '').toString().trim().toLowerCase();
    return data['isAdmin'] == true || role == 'admin' || role == 'superadmin';
  }

  /// Read the global maintenance flag from Firestore.
  Future<bool> isMaintenanceModeEnabled() async {
    try {
      final data = await getSystemSettings();
      return data['maintenanceMode'] == true;
    } catch (e) {
      print('Error checking maintenance mode: $e');
      return false;
    }
  }

  /// Stream the global system settings document.
  Stream<DocumentSnapshot<Map<String, dynamic>>> streamSystemSettings() {
    return _systemSettingsRef.snapshots();
  }

  /// Stream global settings merged with defaults.
  Stream<Map<String, dynamic>> streamResolvedSystemSettings() {
    return _systemSettingsRef.snapshots().map((doc) {
      return {
        ...systemSettingsDefaults,
        ...(doc.data() ?? <String, dynamic>{}),
      };
    });
  }

  /// Read global settings merged with defaults.
  Future<Map<String, dynamic>> getSystemSettings() async {
    final doc = await _systemSettingsRef.get();
    return {...systemSettingsDefaults, ...(doc.data() ?? <String, dynamic>{})};
  }

  /// Parse a setting that may be numeric (10000), formatted string ("$10,000"),
  /// or unlimited.
  double parseMaxTransactionLimit(dynamic value) {
    if (value is num) return value.toDouble();

    final text = (value ?? '').toString().trim().toLowerCase();
    if (text.isEmpty || text == 'unlimited') {
      return double.infinity;
    }

    final numeric = text.replaceAll(RegExp(r'[^0-9.]'), '');
    final parsed = double.tryParse(numeric);
    if (parsed == null || parsed <= 0) {
      return 5000;
    }

    return parsed.clamp(0, 5000).toDouble();
  }

  String formatTransactionLimit(double limit) {
    if (limit == double.infinity) return 'Unlimited';
    return 'â‚¹${limit.toStringAsFixed(0)}';
  }

  /// Per-user preferences consumed by user panel screens.
  Stream<Map<String, dynamic>> streamUserPreferences(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((doc) {
      final data = doc.data() ?? <String, dynamic>{};
      return {
        'emailNotifications': data['emailNotifications'] is bool
            ? data['emailNotifications'] as bool
            : true,
        'pushNotifications': data['pushNotifications'] is bool
            ? data['pushNotifications'] as bool
            : true,
      };
    });
  }

  Future<void> updateUserPreferences(String uid, Map<String, dynamic> updates) {
    return _db.collection('users').doc(uid).set({
      ...updates,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<String> streamDefaultCurrencyCode() {
    return streamResolvedSystemSettings().map(
      (settings) => normalizeCurrencyCode(settings['defaultCurrency']),
    );
  }

  Future<String> getDefaultCurrencyCode() async {
    final settings = await getSystemSettings();
    return normalizeCurrencyCode(settings['defaultCurrency']);
  }
}
