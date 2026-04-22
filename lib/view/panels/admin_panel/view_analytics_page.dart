import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:money_tracking_app/model/money_transaction.dart';
import 'package:money_tracking_app/model/user_model.dart';
import 'package:money_tracking_app/controller/services/firestore_service.dart';
import 'package:money_tracking_app/view/widgets/app_gradient_background.dart';
import 'package:money_tracking_app/view/widgets/glass_card.dart';
import 'package:money_tracking_app/view/utils/app_colors.dart';

class ViewAnalyticsPage extends StatelessWidget {
  const ViewAnalyticsPage({super.key});

  static const List<Color> _categoryColors = [
    Colors.orange,
    Colors.blue,
    Colors.pink,
    Colors.green,
    Colors.purple,
    Colors.teal,
  ];

  FirestoreService get _firestoreService => FirestoreService();

  String _formatCurrency(double value) {
    return NumberFormat.currency(
      locale: 'en_IN',
      symbol: 'â‚¹',
      decimalDigits: 0,
    ).format(value);
  }

  String _formatChange(double current, double previous) {
    if (previous == 0) {
      if (current == 0) return '0.0%';
      return '+100.0%';
    }

    final deltaPercent = ((current - previous) / previous.abs()) * 100;
    final sign = deltaPercent >= 0 ? '+' : '';
    return '$sign${deltaPercent.toStringAsFixed(1)}%';
  }

  bool _sameMonth(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month;
  }

  _AnalyticsData _buildAnalytics(
    List<MoneyTransaction> transactions,
    List<UserModel> users,
  ) {
    final now = DateTime.now();
    final monthStarts = List<DateTime>.generate(
      6,
      (index) => DateTime(now.year, now.month - 5 + index),
    );

    final approvedTransactions = transactions
        .where((t) => t.status.toLowerCase() == 'approved')
        .toList();
    final source = approvedTransactions.isNotEmpty
        ? approvedTransactions
        : transactions;

    final monthlyData = monthStarts.map((monthStart) {
      double income = 0;
      double expense = 0;

      for (final tx in source) {
        if (!_sameMonth(tx.date, monthStart)) continue;
        if (tx.type.toLowerCase() == 'income') {
          income += tx.amount;
        } else {
          expense += tx.amount;
        }
      }

      return {
        'month': DateFormat('MMM').format(monthStart),
        'income': income,
        'expense': expense,
      };
    }).toList();

    double incomeTotal = 0;
    double expenseTotal = 0;
    for (final tx in source) {
      if (tx.type.toLowerCase() == 'income') {
        incomeTotal += tx.amount;
      } else {
        expenseTotal += tx.amount;
      }
    }
    final netSavings = incomeTotal - expenseTotal;

    final thisMonth = DateTime(now.year, now.month);
    final previousMonth = DateTime(now.year, now.month - 1);

    double thisMonthIncome = 0;
    double prevMonthIncome = 0;
    double thisMonthExpense = 0;
    double prevMonthExpense = 0;

    for (final tx in source) {
      final isIncome = tx.type.toLowerCase() == 'income';
      if (_sameMonth(tx.date, thisMonth)) {
        if (isIncome) {
          thisMonthIncome += tx.amount;
        } else {
          thisMonthExpense += tx.amount;
        }
      }
      if (_sameMonth(tx.date, previousMonth)) {
        if (isIncome) {
          prevMonthIncome += tx.amount;
        } else {
          prevMonthExpense += tx.amount;
        }
      }
    }

    final thisMonthNet = thisMonthIncome - thisMonthExpense;
    final prevMonthNet = prevMonthIncome - prevMonthExpense;

    final firstHalf = monthlyData
        .take(3)
        .fold<double>(0, (sum, item) => sum + (item['income'] as double));
    final secondHalf = monthlyData
        .skip(3)
        .fold<double>(0, (sum, item) => sum + (item['income'] as double));

    final avgPerMonth = incomeTotal / 6;
    final avgFirstHalf = firstHalf / 3;
    final avgSecondHalf = secondHalf / 3;

    final kpis = [
      {
        'title': 'Total Revenue',
        'value': _formatCurrency(incomeTotal),
        'change': _formatChange(thisMonthIncome, prevMonthIncome),
        'up': thisMonthIncome >= prevMonthIncome,
        'icon': Icons.trending_up_rounded,
        'color': Colors.green,
      },
      {
        'title': 'Total Expenses',
        'value': _formatCurrency(expenseTotal),
        'change': _formatChange(thisMonthExpense, prevMonthExpense),
        'up': thisMonthExpense <= prevMonthExpense,
        'icon': Icons.trending_down_rounded,
        'color': Colors.red,
      },
      {
        'title': 'Net Savings',
        'value': _formatCurrency(netSavings),
        'change': _formatChange(thisMonthNet, prevMonthNet),
        'up': thisMonthNet >= prevMonthNet,
        'icon': Icons.savings_rounded,
        'color': Colors.blue,
      },
      {
        'title': 'Avg / Month',
        'value': _formatCurrency(avgPerMonth),
        'change': _formatChange(avgSecondHalf, avgFirstHalf),
        'up': avgSecondHalf >= avgFirstHalf,
        'icon': Icons.bar_chart_rounded,
        'color': Colors.orange,
      },
    ];

    final categoryTotals = <String, double>{};
    for (final tx in source.where((t) => t.type.toLowerCase() != 'income')) {
      categoryTotals[tx.category] =
          (categoryTotals[tx.category] ?? 0) + tx.amount;
    }

    final categoryEntries = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final categoryDenominator = categoryEntries.fold<double>(
      0,
      (sum, entry) => sum + entry.value,
    );

    final categoryBreakdown = categoryEntries.isEmpty
        ? [
            {'name': 'No expense data', 'percent': 0.0, 'color': Colors.grey},
          ]
        : categoryEntries.take(6).toList().asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final percent = categoryDenominator == 0
                ? 0.0
                : item.value / categoryDenominator;
            return {
              'name': item.key,
              'percent': percent,
              'color': _categoryColors[index % _categoryColors.length],
            };
          }).toList();

    final topIncomeMonth = monthlyData.reduce((a, b) {
      return (a['income'] as double) >= (b['income'] as double) ? a : b;
    });

    final topExpenseCategory = categoryEntries.isEmpty
        ? null
        : categoryEntries.first;

    final txThisMonth = transactions
        .where((t) => _sameMonth(t.date, thisMonth))
        .length;
    final txPrevMonth = transactions
        .where((t) => _sameMonth(t.date, previousMonth))
        .length;
    final txGrowth = _formatChange(
      txThisMonth.toDouble(),
      txPrevMonth.toDouble(),
    );

    final activeUsers = users.where((u) => u.active).length;
    final savingsRate = incomeTotal == 0
        ? 0.0
        : (netSavings / incomeTotal) * 100;

    final insights = [
      {
        'icon': Icons.emoji_events_rounded,
        'color': Colors.amber,
        'text':
            'Best month: ${topIncomeMonth['month']} (${_formatCurrency(topIncomeMonth['income'] as double)} income)',
      },
      {
        'icon': Icons.warning_amber_rounded,
        'color': Colors.orange,
        'text': topExpenseCategory == null
            ? 'No expense category data available yet.'
            : 'Highest expense category: ${topExpenseCategory.key} (${((topExpenseCategory.value / categoryDenominator) * 100).toStringAsFixed(1)}%)',
      },
      {
        'icon': Icons.trending_up_rounded,
        'color': Colors.green,
        'text':
            'Savings rate: ${savingsRate.toStringAsFixed(1)}% over the last 6 months.',
      },
      {
        'icon': Icons.people_rounded,
        'color': Colors.blue,
        'text':
            'Active users: $activeUsers / ${users.length}. Transactions MoM: $txGrowth.',
      },
    ];

    double maxBarValue = 1;
    for (final item in monthlyData) {
      final income = item['income'] as double;
      final expense = item['expense'] as double;
      if (income > maxBarValue) maxBarValue = income;
      if (expense > maxBarValue) maxBarValue = expense;
    }

    final periodLabel =
        '${DateFormat('MMM yyyy').format(monthStarts.first)} - ${DateFormat('MMM yyyy').format(monthStarts.last)}';

    return _AnalyticsData(
      kpis: kpis,
      monthlyData: monthlyData,
      categoryBreakdown: categoryBreakdown,
      insights: insights,
      maxBarValue: maxBarValue,
      periodLabel: periodLabel,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppGradientBackground(
        child: SafeArea(
          child: StreamBuilder<List<MoneyTransaction>>(
            stream: _firestoreService.streamTransactions(),
            builder: (context, transactionSnapshot) {
              if (transactionSnapshot.hasError) {
                return Center(
                  child: Text(
                    'Failed to load transactions: ${transactionSnapshot.error}',
                  ),
                );
              }

              if (!transactionSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              return StreamBuilder<List<UserModel>>(
                stream: _firestoreService.streamAllUsers(),
                builder: (context, userSnapshot) {
                  if (userSnapshot.hasError) {
                    return Center(
                      child: Text(
                        'Failed to load users: ${userSnapshot.error}',
                      ),
                    );
                  }

                  final analytics = _buildAnalytics(
                    transactionSnapshot.data ?? const <MoneyTransaction>[],
                    userSnapshot.data ?? const <UserModel>[],
                  );

                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back_rounded),
                              onPressed: () => Navigator.pop(context),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Analytics',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.walletAccent.withValues(
                                  alpha: 0.15,
                                ),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                analytics.periodLabel,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.walletAccent,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 1.6,
                          children: analytics.kpis
                              .map((kpi) => _KpiCard(kpi: kpi))
                              .toList(),
                        ),
                        const SizedBox(height: 20),
                        GlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Income vs Expenses',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: const [
                                  _LegendDot(
                                    color: Colors.green,
                                    label: 'Income',
                                  ),
                                  SizedBox(width: 16),
                                  _LegendDot(
                                    color: Colors.red,
                                    label: 'Expense',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                height: 160,
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: analytics.monthlyData.map((d) {
                                    final incomeH =
                                        ((d['income'] as double) /
                                            analytics.maxBarValue) *
                                        140;
                                    final expenseH =
                                        ((d['expense'] as double) /
                                            analytics.maxBarValue) *
                                        140;
                                    return Expanded(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              _Bar(
                                                height: incomeH,
                                                color: Colors.green,
                                              ),
                                              const SizedBox(width: 3),
                                              _Bar(
                                                height: expenseH,
                                                color: Colors.red,
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            d['month'] as String,
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.black.withValues(
                                                alpha: 0.5,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
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
                                'Expense Breakdown by Category',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 14),
                              ...analytics.categoryBreakdown.map(
                                (cat) => _CategoryBar(data: cat),
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
                                'Key Insights',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 12),
                              ...analytics.insights.map(
                                (insight) => _InsightRow(
                                  icon: insight['icon'] as IconData,
                                  color: insight['color'] as Color,
                                  text: insight['text'] as String,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _AnalyticsData {
  final List<Map<String, dynamic>> kpis;
  final List<Map<String, dynamic>> monthlyData;
  final List<Map<String, dynamic>> categoryBreakdown;
  final List<Map<String, dynamic>> insights;
  final double maxBarValue;
  final String periodLabel;

  const _AnalyticsData({
    required this.kpis,
    required this.monthlyData,
    required this.categoryBreakdown,
    required this.insights,
    required this.maxBarValue,
    required this.periodLabel,
  });
}

// â”€â”€ Helper Widgets â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _KpiCard extends StatelessWidget {
  final Map<String, dynamic> kpi;
  const _KpiCard({required this.kpi});

  @override
  Widget build(BuildContext context) {
    final color = kpi['color'] as Color;
    final isUp = kpi['up'] as bool;
    return GlassCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(kpi['icon'] as IconData, color: color, size: 18),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: (isUp ? Colors.green : Colors.red).withValues(
                    alpha: 0.15,
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  kpi['change'] as String,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isUp ? Colors.green : Colors.red,
                  ),
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                kpi['value'] as String,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                kpi['title'] as String,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.black.withValues(alpha: 0.55),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  final double height;
  final Color color;
  const _Bar({required this.height, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: height.clamp(4.0, 140.0),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.8),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.black.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}

class _CategoryBar extends StatelessWidget {
  final Map<String, dynamic> data;
  const _CategoryBar({required this.data});

  @override
  Widget build(BuildContext context) {
    final percent = data['percent'] as double;
    final color = data['color'] as Color;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                data['name'] as String,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${(percent * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 8,
              backgroundColor: Colors.black.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  const _InsightRow({
    required this.icon,
    required this.color,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
