import 'package:cloud_firestore/cloud_firestore.dart';
import 'notification_service.dart';

class BudgetService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _userTransactionsRef(String uid) {
    return _db.collection('users').doc(uid).collection('transactions');
  }

  CollectionReference<Map<String, dynamic>> _userBudgetsRef(String uid) {
    return _db.collection('users').doc(uid).collection('budgets');
  }

  DocumentReference<Map<String, dynamic>> _notificationMetaRef(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('budget_meta')
        .doc('notifications');
  }

  String monthKey(DateTime month) {
    final normalized = DateTime(month.year, month.month, 1);
    return '${normalized.year}-${normalized.month.toString().padLeft(2, '0')}';
  }

  DateTime monthStart(DateTime month) => DateTime(month.year, month.month, 1);

  DateTime nextMonthStart(DateTime month) =>
      DateTime(month.year, month.month + 1, 1);

  DocumentReference<Map<String, dynamic>> _monthlyBudgetRef({
    required String uid,
    required DateTime month,
  }) {
    return _userBudgetsRef(uid).doc(monthKey(month));
  }

  Future<void> setCategoryBudget({
    required String uid,
    required DateTime month,
    required String category,
    required double amount,
  }) async {
    final normalizedCategory = category.trim();
    if (uid.trim().isEmpty || normalizedCategory.isEmpty) {
      throw StateError('User id and category are required.');
    }

    await _monthlyBudgetRef(uid: uid, month: month).set({
      'uid': uid,
      'monthKey': monthKey(month),
      'categories': {normalizedCategory: amount},
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> resetCategoryBudgets({
    required String uid,
    required DateTime month,
    required Iterable<String> categories,
  }) async {
    if (uid.trim().isEmpty) {
      throw StateError('User id is required.');
    }

    final mapped = <String, double>{
      for (final category in categories)
        if (category.trim().isNotEmpty) category.trim(): 0,
    };

    await _monthlyBudgetRef(uid: uid, month: month).set({
      'uid': uid,
      'monthKey': monthKey(month),
      'categories': mapped,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<Map<String, double>> streamCategoryBudgets({
    required String uid,
    required DateTime month,
  }) {
    if (uid.trim().isEmpty) {
      return const Stream<Map<String, double>>.empty();
    }

    return _monthlyBudgetRef(uid: uid, month: month).snapshots().map((doc) {
      final raw =
          (doc.data()?['categories'] as Map<String, dynamic>?) ??
          <String, dynamic>{};
      return {
        for (final entry in raw.entries)
          entry.key.toString(): (entry.value as num?)?.toDouble() ?? 0,
      };
    });
  }

  Stream<Map<String, double>> streamMonthlyExpenseByCategory({
    required String uid,
    required DateTime month,
  }) {
    if (uid.trim().isEmpty) {
      return const Stream<Map<String, double>>.empty();
    }

    final start = monthStart(month);
    final end = nextMonthStart(month);

    return _db
        .collection('users')
        .doc(uid)
        .collection('transactions')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThan: Timestamp.fromDate(end))
        .snapshots()
        .map((snapshot) {
          final totals = <String, double>{};

          for (final doc in snapshot.docs) {
            final data = doc.data();
            final isExpense =
                (data['type'] ?? '').toString().toLowerCase() == 'expense';
            final isApproved =
                (data['status'] ?? '').toString().toLowerCase() == 'approved';
            if (!isExpense || !isApproved) continue;

            final category = (data['category'] ?? 'Other').toString().trim();
            final amount = (data['amount'] as num?)?.toDouble() ?? 0;
            totals[category] = (totals[category] ?? 0) + amount;
          }

          return totals;
        });
  }

  Future<double> _getMonthlySpentForCategory({
    required String uid,
    required DateTime month,
    required String category,
  }) async {
    final normalizedCategory = category.trim();
    if (uid.trim().isEmpty || normalizedCategory.isEmpty) {
      return 0;
    }

    final start = monthStart(month);
    final end = nextMonthStart(month);

    final snapshot = await _userTransactionsRef(uid)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThan: Timestamp.fromDate(end))
        .get();

    double total = 0;
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final isExpense =
          (data['type'] ?? '').toString().toLowerCase() == 'expense';
      final isApproved =
          (data['status'] ?? '').toString().toLowerCase() == 'approved';
      final resolvedCategory = (data['category'] ?? '').toString().trim();
      if (!isExpense || !isApproved || resolvedCategory != normalizedCategory) {
        continue;
      }

      total += (data['amount'] as num?)?.toDouble() ?? 0;
    }
    return total;
  }

  Future<double> _getCategoryBudget({
    required String uid,
    required DateTime month,
    required String category,
  }) async {
    final normalizedCategory = category.trim();
    if (uid.trim().isEmpty || normalizedCategory.isEmpty) {
      return 0;
    }

    final doc = await _monthlyBudgetRef(uid: uid, month: month).get();
    final categories =
        (doc.data()?['categories'] as Map<String, dynamic>?) ??
        <String, dynamic>{};

    return (categories[normalizedCategory] as num?)?.toDouble() ?? 0;
  }

  Future<void> checkBudgetAfterTransaction({
    required String uid,
    required DateTime transactionDate,
    required String category,
    required double transactionAmount,
    required String transactionType,
  }) async {
    if (uid.trim().isEmpty) return;
    if (transactionType.trim().toLowerCase() != 'expense') return;

    final normalizedCategory = category.trim();
    if (normalizedCategory.isEmpty) return;

    final month = DateTime(transactionDate.year, transactionDate.month, 1);
    await maybeSendNewMonthReminder(uid: uid, month: month);

    final budget = await _getCategoryBudget(
      uid: uid,
      month: month,
      category: normalizedCategory,
    );
    if (budget <= 0) return;

    final spent = await _getMonthlySpentForCategory(
      uid: uid,
      month: month,
      category: normalizedCategory,
    );
    final previousSpent = (spent - transactionAmount).clamp(0, double.infinity);
    final warningThreshold = budget * 0.8;

    if (spent >= budget && previousSpent < budget) {
      await NotificationService.instance.showBudgetAlert(
        title: 'Budget Exceeded',
        body:
            '$normalizedCategory spending reached ${spent.toStringAsFixed(0)} of ${budget.toStringAsFixed(0)} for ${monthKey(month)}.',
      );
      return;
    }

    if (spent >= warningThreshold && previousSpent < warningThreshold) {
      await NotificationService.instance.showBudgetAlert(
        title: 'Budget Warning',
        body:
            '$normalizedCategory spending reached ${(spent / budget * 100).toStringAsFixed(0)}% of your monthly budget.',
      );
    }

    final totalBudget = await _getMonthlyBudgetTotal(uid: uid, month: month);
    if (totalBudget <= 0) return;

    final totalSpent = await _getMonthlySpentTotal(uid: uid, month: month);
    final previousTotalSpent = (totalSpent - transactionAmount).clamp(
      0,
      double.infinity,
    );
    final totalWarningThreshold = totalBudget * 0.8;

    if (totalSpent >= totalBudget && previousTotalSpent < totalBudget) {
      await NotificationService.instance.showBudgetAlert(
        title: 'Budget Exceeded',
        body:
            'You have exceeded your ${monthKey(month)} budget: ₹${totalSpent.toStringAsFixed(0)} / ₹${totalBudget.toStringAsFixed(0)}.',
      );
      return;
    }

    if (totalSpent >= totalWarningThreshold &&
        previousTotalSpent < totalWarningThreshold) {
      await NotificationService.instance.showBudgetAlert(
        title: 'Budget Warning',
        body:
            'You have used ${(totalSpent / totalBudget * 100).toStringAsFixed(0)}% of your ${monthKey(month)} budget.',
      );
    }
  }

  Future<double> _getMonthlyBudgetTotal({
    required String uid,
    required DateTime month,
  }) async {
    final doc = await _monthlyBudgetRef(uid: uid, month: month).get();
    final categories =
        (doc.data()?['categories'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};

    return categories.values.fold<double>(0, (total, value) {
      return total + ((value as num?)?.toDouble() ?? 0);
    });
  }

  Future<double> _getMonthlySpentTotal({
    required String uid,
    required DateTime month,
  }) async {
    final start = monthStart(month);
    final end = nextMonthStart(month);

    final snapshot = await _userTransactionsRef(uid)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThan: Timestamp.fromDate(end))
        .get();

    return snapshot.docs.fold<double>(0, (total, doc) {
      final data = doc.data();
      final isExpense =
          (data['type'] ?? '').toString().toLowerCase() == 'expense';
      final isApproved =
          (data['status'] ?? '').toString().toLowerCase() == 'approved';
      if (!isExpense || !isApproved) {
        return total;
      }

      return total + ((data['amount'] as num?)?.toDouble() ?? 0);
    });
  }

  Future<void> maybeSendNewMonthReminder({
    required String uid,
    DateTime? month,
  }) async {
    if (uid.trim().isEmpty) return;

    final activeMonth = DateTime(
      (month ?? DateTime.now()).year,
      (month ?? DateTime.now()).month,
      1,
    );
    final activeMonthKey = monthKey(activeMonth);

    final metaRef = _notificationMetaRef(uid);
    final metaDoc = await metaRef.get();
    final lastReminderMonth = (metaDoc.data()?['lastReminderMonth'] ?? '')
        .toString();

    if (lastReminderMonth == activeMonthKey) {
      return;
    }

    await NotificationService.instance.showBudgetAlert(
      title: 'New Month Reminder',
      body: 'Set your budget for $activeMonthKey to stay on track.',
    );

    await metaRef.set({
      'lastReminderMonth': activeMonthKey,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // Save budget limit (example: 10000)
  Future<void> setMonthlyBudget(double limit, {required String uid}) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('settings')
        .doc('budget')
        .set({
          'monthlyLimit': limit,
          'warnPercent': 80, // warning at 80%
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  // Get budget data
  Future<Map<String, dynamic>> _getBudget(String uid) async {
    final doc = await _db
        .collection('users')
        .doc(uid)
        .collection('settings')
        .doc('budget')
        .get();
    final data = doc.data() ?? {};
    return {
      'monthlyLimit': (data['monthlyLimit'] ?? 0).toDouble(),
      'warnPercent': (data['warnPercent'] ?? 80).toDouble(),
    };
  }

  // Calculate this month expense total
  Future<double> getThisMonthExpenseTotal({required String uid}) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 1);

    final q = await _userTransactionsRef(uid)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThan: Timestamp.fromDate(end))
        .get();

    double total = 0;
    for (final d in q.docs) {
      final data = d.data();
      final isExpense =
          (data['type'] ?? '').toString().toLowerCase() == 'expense';
      final isApproved =
          (data['status'] ?? '').toString().toLowerCase() == 'approved';
      if (!isExpense || !isApproved) continue;

      total += (data['amount'] ?? 0).toDouble();
    }
    return total;
  }

  // Call this AFTER saving an expense
  Future<void> checkAndNotifyBudget({required String uid}) async {
    final budget = await _getBudget(uid);
    final limit = budget['monthlyLimit'] as double;
    final warnPercent = budget['warnPercent'] as double;

    if (limit <= 0) return; // budget not set

    final spent = await getThisMonthExpenseTotal(uid: uid);
    final warnAt = (warnPercent / 100) * limit;

    if (spent >= limit) {
      await NotificationService.instance.showBudgetAlert(
        title: "Budget Exceeded ⚠️",
        body:
            "You spent ₹${spent.toStringAsFixed(0)} / ₹${limit.toStringAsFixed(0)} this month.",
      );
    } else if (spent >= warnAt) {
      await NotificationService.instance.showBudgetAlert(
        title: "Budget Warning",
        body:
            "You used ${warnPercent.toStringAsFixed(0)}% of your budget: ₹${spent.toStringAsFixed(0)} / ₹${limit.toStringAsFixed(0)}",
      );
    }
  }
}
