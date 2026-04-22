import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:money_tracking_app/model/transaction_model.dart';
import 'package:money_tracking_app/controller/services/transaction_service.dart';
import 'package:money_tracking_app/view/utils/app_colors.dart';
import 'package:money_tracking_app/view/widgets/app_gradient_background.dart';
import 'package:money_tracking_app/view/widgets/glass_card.dart';

class UserTransactionHistoryPage extends StatefulWidget {
  const UserTransactionHistoryPage({super.key});

  @override
  State<UserTransactionHistoryPage> createState() =>
      _UserTransactionHistoryPageState();
}

class _UserTransactionHistoryPageState
    extends State<UserTransactionHistoryPage> {
  final TransactionService _transactionService = TransactionService();
  final TextEditingController _searchController = TextEditingController();
  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: 'â‚¹',
    decimalDigits: 0,
  );

  String _selectedStatus = 'All';
  String _sortBy = 'Newest';
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<TransactionModel> _applyFilters(List<TransactionModel> transactions) {
    Iterable<TransactionModel> filtered = transactions;

    if (_selectedStatus != 'All') {
      filtered = filtered.where(
        (transaction) =>
            transaction.status.toLowerCase() == _selectedStatus.toLowerCase(),
      );
    }

    if (_query.isNotEmpty) {
      filtered = filtered.where((transaction) {
        final haystack = [
          transaction.category,
          transaction.description,
          transaction.status,
          transaction.type,
        ].join(' ').toLowerCase();
        return haystack.contains(_query);
      });
    }

    final list = filtered.toList();
    list.sort((a, b) {
      final comparison = a.date.compareTo(b.date);
      return _sortBy == 'Newest' ? -comparison : comparison;
    });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      body: AppGradientBackground(
        child: SafeArea(
          child: currentUser == null
              ? const Center(child: Text('Please log in to view history.'))
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.arrow_back_rounded),
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Transaction History',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child:
                          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                            stream: FirebaseFirestore.instance
                                .collection('users')
                                .doc(currentUser.uid)
                                .snapshots(),
                            builder: (context, snapshot) {
                              final balance =
                                  (snapshot.data?.data()?['balance'] ?? 0)
                                      as num;
                              return GlassCard(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: AppColors.walletAccent
                                            .withValues(alpha: 0.14),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: const Icon(
                                        Icons.account_balance_wallet_rounded,
                                        color: AppColors.walletAccent,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Current Balance',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.black54,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _currencyFormat.format(
                                            balance.toDouble(),
                                          ),
                                          style: const TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search_rounded),
                          hintText: 'Search history',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 44,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        scrollDirection: Axis.horizontal,
                        itemBuilder: (context, index) {
                          final status = const [
                            'All',
                            'Pending',
                            'Approved',
                            'Rejected',
                          ][index];
                          final selected = status == _selectedStatus;
                          return FilterChip(
                            selected: selected,
                            label: Text(status),
                            onSelected: (_) =>
                                setState(() => _selectedStatus = status),
                            selectedColor: AppColors.walletAccent.withValues(alpha: 
                              0.18,
                            ),
                            labelStyle: TextStyle(
                              color: selected
                                  ? AppColors.walletAccent
                                  : Colors.black87,
                              fontWeight: FontWeight.w700,
                            ),
                          );
                        },
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemCount: 4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: DropdownButton<String>(
                          value: _sortBy,
                          items: const [
                            DropdownMenuItem(
                              value: 'Newest',
                              child: Text('Newest'),
                            ),
                            DropdownMenuItem(
                              value: 'Oldest',
                              child: Text('Oldest'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() => _sortBy = value);
                          },
                        ),
                      ),
                    ),
                    Expanded(
                      child: StreamBuilder<List<TransactionModel>>(
                        stream: _transactionService.getUserTransactions(
                          currentUser.uid,
                        ),
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return Center(
                              child: Text(
                                'Failed to load history: ${snapshot.error}',
                              ),
                            );
                          }

                          if (!snapshot.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          final transactions = _applyFilters(
                            snapshot.data ?? [],
                          );
                          if (transactions.isEmpty) {
                            return const Center(
                              child: Text('No transactions found.'),
                            );
                          }

                          return ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                            itemCount: transactions.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final transaction = transactions[index];
                              final isIncome = transaction.type == 'income';
                              return GlassCard(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 44,
                                          height: 44,
                                          decoration: BoxDecoration(
                                            color:
                                                (isIncome
                                                        ? Colors.green
                                                        : Colors.red)
                                                    .withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                          ),
                                          child: Icon(
                                            isIncome
                                                ? Icons.trending_up_rounded
                                                : Icons.trending_down_rounded,
                                            color: isIncome
                                                ? Colors.green
                                                : Colors.red,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                transaction.category,
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                DateFormat(
                                                  'dd MMM yyyy, hh:mm a',
                                                ).format(transaction.date),
                                                style: TextStyle(
                                                  color: Colors.black
                                                      .withValues(alpha: 0.55),
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        _StatusBadge(
                                          status: transaction.status,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      transaction.description,
                                      style: TextStyle(
                                        color: Colors.black.withValues(alpha: 0.72),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Text(
                                          _currencyFormat.format(
                                            transaction.amount,
                                          ),
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w900,
                                            color: isIncome
                                                ? Colors.green
                                                : Colors.red,
                                          ),
                                        ),
                                        const Spacer(),
                                        Text(
                                          transaction.type.toUpperCase(),
                                          style: TextStyle(
                                            color: Colors.black.withValues(alpha: 
                                              0.55,
                                            ),
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if ((transaction.rejectionReason ?? '')
                                        .isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        'Rejected reason: ${transaction.rejectionReason}',
                                        style: TextStyle(
                                          color: Colors.red.shade700,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final normalized = status.toLowerCase();
    Color color;
    switch (normalized) {
      case 'approved':
        color = Colors.green;
        break;
      case 'rejected':
        color = Colors.red;
        break;
      default:
        color = Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 11,
        ),
      ),
    );
  }
}
