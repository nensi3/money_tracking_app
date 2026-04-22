import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:money_tracking_app/model/money_transaction.dart';
import 'package:money_tracking_app/controller/services/firestore_service.dart';

class UserTransactionsProvider extends ChangeNotifier {
  UserTransactionsProvider({required String userId, FirestoreService? service})
    : _userId = userId,
      _service = service ?? FirestoreService() {
    _listen();
  }

  final String _userId;
  final FirestoreService _service;

  StreamSubscription<List<MoneyTransaction>>? _subscription;
  bool _isLoading = true;
  String? _error;
  List<MoneyTransaction> _transactions = const [];

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<MoneyTransaction> get transactions => _transactions;

  List<MoneyTransaction> get approvedTransactions =>
      _transactions.where((t) => t.status == 'approved').toList();

  double get totalIncome => approvedTransactions
      .where((t) => t.type == 'income')
      .fold(0, (sum, t) => sum + t.amount);

  double get totalExpense => approvedTransactions
      .where((t) => t.type == 'expense')
      .fold(0, (sum, t) => sum + t.amount);

  double get balance => totalIncome - totalExpense;

  int get transactionCount => _transactions.length;

  Future<void> refresh() async {
    _error = null;
    notifyListeners();
    try {
      final latest = await _service.fetchTransactionsOnce(userId: _userId);
      _transactions = latest;
    } catch (e) {
      _error = 'Failed to refresh transactions: $e';
    }
    notifyListeners();
  }

  void _listen() {
    _subscription = _service
        .streamTransactions(userId: _userId)
        .listen(
          (data) {
            _transactions = data;
            _error = null;
            _isLoading = false;
            notifyListeners();
          },
          onError: (error) {
            _error = 'Failed to load transactions: $error';
            _isLoading = false;
            notifyListeners();
          },
        );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
