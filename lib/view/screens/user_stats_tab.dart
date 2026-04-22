import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:money_tracking_app/controller/providers/user_transactions_provider.dart';
import 'package:money_tracking_app/controller/services/firestore_service.dart';
import 'package:money_tracking_app/view/widgets/category_progress_bar.dart';
import 'package:money_tracking_app/view/widgets/glass_card.dart';

class UserStatsTab extends StatelessWidget {
  UserStatsTab({super.key});

  final FirestoreService _service = FirestoreService();
  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: 'Rs ',
    decimalDigits: 0,
  );

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      return const Center(child: Text('Please log in to view stats.'));
    }

    return ChangeNotifierProvider(
      create: (_) =>
          UserTransactionsProvider(userId: userId, service: _service),
      child: Consumer<UserTransactionsProvider>(
        builder: (context, txProvider, _) {
          if (txProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (txProvider.error != null) {
            return Center(child: Text(txProvider.error!));
          }

          final transactions = txProvider.transactions;
          final approvedTransactions = txProvider.approvedTransactions;
          final income = txProvider.totalIncome;
          final expense = txProvider.totalExpense;
          final balance = txProvider.balance;
          final totalTransactions = txProvider.transactionCount;

          final approvedExpenseTransactions = approvedTransactions
              .where((transaction) => transaction.type == 'expense')
              .toList();

          final averageSpend = approvedExpenseTransactions.isEmpty
              ? 0.0
              : expense / approvedExpenseTransactions.length;

          final expenseRatio = income <= 0 ? 0.0 : ((expense / income) * 100);

          final latestActivity = transactions.isEmpty
              ? 'No transactions yet'
              : transactions.first.category;

          final expenseByCategory = <String, double>{};
          for (final transaction in approvedExpenseTransactions) {
            expenseByCategory.update(
              transaction.category,
              (value) => value + transaction.amount,
              ifAbsent: () => transaction.amount,
            );
          }

          final topCategories = expenseByCategory.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));

          return LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 32,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      Text(
                        'Your Stats',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Track balance, spending, and category performance.',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.black.withValues(alpha: 0.58),
                        ),
                      ),
                      const SizedBox(height: 18),
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1.15,
                        children: [
                          _StatsCard(
                            title: 'Balance',
                            value: balance,
                            color: const Color(0xFF2563EB),
                            icon: Icons.account_balance_wallet_rounded,
                          ),
                          _StatsCard(
                            title: 'Income',
                            value: income,
                            color: Colors.green,
                            icon: Icons.trending_up_rounded,
                          ),
                          _StatsCard(
                            title: 'Expense',
                            value: expense,
                            color: Colors.red,
                            icon: Icons.trending_down_rounded,
                          ),
                          _StatsCard(
                            title: 'Transactions',
                            value: totalTransactions.toDouble(),
                            color: const Color(0xFFF59E0B),
                            icon: Icons.receipt_long_rounded,
                            compact: true,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      GlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Spending Overview',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 14),
                            _OverviewRow(
                              label: 'Expense ratio',
                              value: income <= 0
                                  ? 'No income yet'
                                  : '${expenseRatio.clamp(0, 999).toStringAsFixed(0)}% of income',
                            ),
                            const SizedBox(height: 10),
                            _OverviewRow(
                              label: 'Average expense',
                              value: averageSpend == 0
                                  ? _currencyFormat.format(0)
                                  : _currencyFormat.format(averageSpend),
                            ),
                            const SizedBox(height: 10),
                            _OverviewRow(
                              label: 'Latest activity',
                              value: latestActivity,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      GlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Top Categories',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 14),
                            if (topCategories.isEmpty)
                              const Text(
                                'No category activity yet.',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black54,
                                ),
                              )
                            else
                              ...topCategories
                                  .take(5)
                                  .map(
                                    (entry) => Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 10,
                                      ),
                                      child: CategoryProgressBar(
                                        category: entry.key,
                                        amount: entry.value,
                                        maxAmount: topCategories.first.value,
                                      ),
                                    ),
                                  ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  final String title;
  final double value;
  final Color color;
  final IconData icon;
  final bool compact;

  const _StatsCard({
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          Text(
            compact
                ? value.toStringAsFixed(0)
                : NumberFormat.compact().format(value),
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.black.withValues(alpha: 0.62),
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewRow extends StatelessWidget {
  final String label;
  final String value;

  const _OverviewRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.black.withValues(alpha: 0.62),
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}
