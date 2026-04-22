import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:money_tracking_app/model/transaction_model.dart';
import 'package:money_tracking_app/controller/services/transaction_service.dart';
import 'package:money_tracking_app/view/utils/app_colors.dart';
import 'package:money_tracking_app/view/widgets/app_gradient_background.dart';
import 'package:money_tracking_app/view/widgets/glass_card.dart';

class SpendingTrendsPage extends StatefulWidget {
  const SpendingTrendsPage({super.key});

  @override
  State<SpendingTrendsPage> createState() => _SpendingTrendsPageState();
}

class _SpendingTrendsPageState extends State<SpendingTrendsPage> {
  final TransactionService _transactionService = TransactionService();
  final NumberFormat _money = NumberFormat.currency(
    locale: 'en_IN',
    symbol: 'Rs ',
    decimalDigits: 0,
  );

  String _selectedView = 'Monthly';

  static const List<Color> _trendColors = [
    Color(0xFFFF6B6B),
    Color(0xFF4ECDC4),
    Color(0xFF95E1D3),
    Color(0xFFFFE66D),
    Color(0xFF74B9FF),
    Color(0xFFA29BFE),
  ];

  DateTime _monthStart(DateTime d) => DateTime(d.year, d.month, 1);

  DateTime _weekStart(DateTime d) {
    final normalized = DateTime(d.year, d.month, d.day);
    return normalized.subtract(Duration(days: normalized.weekday - 1));
  }

  DateTime _quarterStart(DateTime d) {
    final qMonth = ((d.month - 1) ~/ 3) * 3 + 1;
    return DateTime(d.year, qMonth, 1);
  }

  String _shortWeekLabel(DateTime start) {
    final end = start.add(const Duration(days: 6));
    return '${DateFormat('d').format(start)}-${DateFormat('d MMM').format(end)}';
  }

  String _quarterLabel(DateTime start) {
    final quarter = ((start.month - 1) ~/ 3) + 1;
    return 'Q$quarter ${start.year.toString().substring(2)}';
  }

  List<DateTime> _recentBuckets() {
    final now = DateTime.now();

    switch (_selectedView) {
      case 'Weekly':
        final current = _weekStart(now);
        return List.generate(
          6,
          (i) => current.subtract(Duration(days: (5 - i) * 7)),
        );
      case 'Quarterly':
        final current = _quarterStart(now);
        return List.generate(4, (i) {
          final shift = 3 * (3 - i);
          return DateTime(current.year, current.month - shift, 1);
        });
      case 'Monthly':
      default:
        final current = _monthStart(now);
        return List.generate(
          6,
          (i) => DateTime(current.year, current.month - (5 - i), 1),
        );
    }
  }

  DateTime _bucketFor(DateTime date) {
    switch (_selectedView) {
      case 'Weekly':
        return _weekStart(date);
      case 'Quarterly':
        return _quarterStart(date);
      case 'Monthly':
      default:
        return _monthStart(date);
    }
  }

  String _bucketLabel(DateTime bucket) {
    switch (_selectedView) {
      case 'Weekly':
        return _shortWeekLabel(bucket);
      case 'Quarterly':
        return _quarterLabel(bucket);
      case 'Monthly':
      default:
        return DateFormat('MMM').format(bucket);
    }
  }

  List<Map<String, dynamic>> _aggregateTrendData(List<TransactionModel> all) {
    final approved = all.where((t) => t.status.toLowerCase() == 'approved');
    final buckets = _recentBuckets();
    final bucketSet = buckets.map((b) => b.millisecondsSinceEpoch).toSet();

    final result = <Map<String, dynamic>>[];

    for (final bucket in buckets) {
      double income = 0;
      double expense = 0;

      for (final t in approved) {
        final txBucket = _bucketFor(t.date);
        if (!bucketSet.contains(txBucket.millisecondsSinceEpoch)) continue;
        if (txBucket != bucket) continue;

        if (t.type.toLowerCase() == 'income') {
          income += t.amount;
        } else if (t.type.toLowerCase() == 'expense') {
          expense += t.amount;
        }
      }

      result.add({
        'period': _bucketLabel(bucket),
        'income': income,
        'expense': expense,
        'savings': income - expense,
      });
    }

    return result;
  }

  List<Map<String, dynamic>> _buildCategoryTrends(List<TransactionModel> all) {
    final approvedExpenses = all.where(
      (t) =>
          t.status.toLowerCase() == 'approved' &&
          t.type.toLowerCase() == 'expense',
    );

    final months = List.generate(6, (i) {
      final now = DateTime.now();
      return DateTime(now.year, now.month - (5 - i), 1);
    });

    final categoryMonthly = <String, List<double>>{};

    for (final m in months) {
      final monthTotals = <String, double>{};
      for (final tx in approvedExpenses) {
        if (tx.date.year == m.year && tx.date.month == m.month) {
          final cat = tx.category.trim().isEmpty ? 'Other' : tx.category.trim();
          monthTotals[cat] = (monthTotals[cat] ?? 0) + tx.amount;
        }
      }

      final existingCategories = categoryMonthly.keys.toList();
      for (final existing in existingCategories) {
        categoryMonthly[existing]!.add(monthTotals[existing] ?? 0);
      }

      for (final entry in monthTotals.entries) {
        if (!categoryMonthly.containsKey(entry.key)) {
          categoryMonthly[entry.key] = List.filled(
            months.indexOf(m),
            0,
            growable: true,
          );
          categoryMonthly[entry.key]!.add(entry.value);
        }
      }
    }

    final sorted = categoryMonthly.entries.toList()
      ..sort((a, b) {
        final aTotal = a.value.fold<double>(0, (s, e) => s + e);
        final bTotal = b.value.fold<double>(0, (s, e) => s + e);
        return bTotal.compareTo(aTotal);
      });

    final top = sorted.take(6).toList();
    return List.generate(top.length, (i) {
      final entry = top[i];
      return {
        'name': entry.key,
        'color': _trendColors[i % _trendColors.length],
        'data': entry.value,
      };
    });
  }

  List<Map<String, dynamic>> _buildInsights(
    List<Map<String, dynamic>> trendData,
    List<Map<String, dynamic>> categoryTrends,
  ) {
    if (trendData.isEmpty) {
      return const [
        {
          'icon': Icons.info_outline_rounded,
          'color': Colors.blue,
          'title': 'No Trend Data Yet',
          'desc': 'Approve some transactions to view spending insights.',
        },
      ];
    }

    final insights = <Map<String, dynamic>>[];

    if (trendData.length >= 2) {
      final latest = trendData.last;
      final previous = trendData[trendData.length - 2];
      final latestSavings = (latest['savings'] as double);
      final previousSavings = (previous['savings'] as double);
      final delta = latestSavings - previousSavings;
      final directionUp = delta >= 0;

      insights.add({
        'icon': directionUp
            ? Icons.trending_up_rounded
            : Icons.trending_down_rounded,
        'color': directionUp ? Colors.green : Colors.red,
        'title': directionUp ? 'Savings Improved' : 'Savings Declined',
        'desc':
            'Savings changed by ${_money.format(delta.abs())} compared to previous period.',
      });
    }

    final highestSavings = trendData.reduce((a, b) {
      return (a['savings'] as double) >= (b['savings'] as double) ? a : b;
    });

    insights.add({
      'icon': Icons.star_rounded,
      'color': Colors.amber,
      'title': 'Best Savings Period',
      'desc':
          '${highestSavings['period']} recorded ${_money.format(highestSavings['savings'] as double)} savings.',
    });

    if (categoryTrends.isNotEmpty) {
      final top = categoryTrends.first;
      final total = (top['data'] as List<double>).fold<double>(
        0,
        (s, e) => s + e,
      );
      insights.add({
        'icon': Icons.category_rounded,
        'color': Colors.deepPurple,
        'title': 'Top Spend Category',
        'desc':
            '${top['name']} had the highest spend over 6 months: ${_money.format(total)}.',
      });
    }

    return insights;
  }

  double _maxValue(List<Map<String, dynamic>> data) {
    var max = 0.0;
    for (final d in data) {
      final income = (d['income'] as double).abs();
      final expense = (d['expense'] as double).abs();
      final savings = (d['savings'] as double).abs();
      if (income > max) max = income;
      if (expense > max) max = expense;
      if (savings > max) max = savings;
    }
    return max <= 0 ? 1 : max;
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      body: AppGradientBackground(
        child: SafeArea(
          child: currentUser == null
              ? const Center(
                  child: Text(
                    'Please sign in to view spending trends.',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                )
              : StreamBuilder<List<TransactionModel>>(
                  stream: _transactionService.getUserTransactions(
                    currentUser.uid,
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final all = snapshot.data ?? const <TransactionModel>[];
                    final trendData = _aggregateTrendData(all);
                    final categoryTrends = _buildCategoryTrends(all);
                    final insights = _buildInsights(trendData, categoryTrends);

                    final max = _maxValue(trendData);
                    final totalIncome = trendData.fold<double>(
                      0,
                      (s, d) => s + (d['income'] as double),
                    );
                    final totalExpense = trendData.fold<double>(
                      0,
                      (s, d) => s + (d['expense'] as double),
                    );
                    final avgSavings = trendData.isEmpty
                        ? 0
                        : trendData.fold<double>(
                                0,
                                (s, d) => s + (d['savings'] as double),
                              ) /
                              trendData.length;

                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                          child: Row(
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
                                  'Spending Trends',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: ['Weekly', 'Monthly', 'Quarterly'].map((
                              v,
                            ) {
                              final isActive = v == _selectedView;
                              return Expanded(
                                child: GestureDetector(
                                  onTap: () =>
                                      setState(() => _selectedView = v),
                                  child: Container(
                                    margin: EdgeInsets.only(
                                      right: v != 'Quarterly' ? 8 : 0,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isActive
                                          ? AppColors.walletAccent
                                          : Colors.white.withValues(
                                              alpha: 0.55,
                                            ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      v,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: isActive
                                            ? Colors.white
                                            : Colors.black.withValues(
                                                alpha: 0.65,
                                              ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    _KpiTile(
                                      label: 'Total Income',
                                      value: _money.format(totalIncome),
                                      color: Colors.green,
                                      icon: Icons.arrow_downward_rounded,
                                    ),
                                    const SizedBox(width: 10),
                                    _KpiTile(
                                      label: 'Total Expense',
                                      value: _money.format(totalExpense),
                                      color: Colors.red,
                                      icon: Icons.arrow_upward_rounded,
                                    ),
                                    const SizedBox(width: 10),
                                    _KpiTile(
                                      label: 'Avg Savings',
                                      value: _money.format(avgSavings),
                                      color: Colors.blue,
                                      icon: Icons.savings_rounded,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                GlassCard(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text(
                                            'Income vs Expense',
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          Row(
                                            children: const [
                                              _LegendDot(
                                                color: Colors.green,
                                                label: 'Income',
                                              ),
                                              SizedBox(width: 12),
                                              _LegendDot(
                                                color: Colors.red,
                                                label: 'Expense',
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      SizedBox(
                                        height: 170,
                                        child: trendData.isEmpty
                                            ? const Center(
                                                child: Text(
                                                  'No approved transactions yet.',
                                                ),
                                              )
                                            : Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.end,
                                                children: trendData.map((d) {
                                                  final ih =
                                                      ((d['income'] as double) /
                                                          max) *
                                                      140;
                                                  final eh =
                                                      ((d['expense']
                                                              as double) /
                                                          max) *
                                                      140;
                                                  return Expanded(
                                                    child: Column(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment.end,
                                                      children: [
                                                        Row(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .center,
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .end,
                                                          children: [
                                                            _Bar(
                                                              height: ih,
                                                              color:
                                                                  Colors.green,
                                                            ),
                                                            const SizedBox(
                                                              width: 3,
                                                            ),
                                                            _Bar(
                                                              height: eh,
                                                              color: Colors.red,
                                                            ),
                                                          ],
                                                        ),
                                                        const SizedBox(
                                                          height: 4,
                                                        ),
                                                        Text(
                                                          d['period'] as String,
                                                          style: TextStyle(
                                                            fontSize: 10,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color: Colors.black
                                                                .withValues(
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
                                const SizedBox(height: 14),
                                GlassCard(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Savings Trend',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: trendData.map((d) {
                                          final savings =
                                              d['savings'] as double;
                                          final maxSavings = trendData
                                              .map(
                                                (x) => x['savings'] as double,
                                              )
                                              .fold<double>(
                                                0,
                                                (a, b) =>
                                                    a.abs() > b.abs() ? a : b,
                                              )
                                              .abs();
                                          final h = maxSavings == 0
                                              ? 4.0
                                              : ((savings.abs() / maxSavings) *
                                                        90)
                                                    .clamp(4.0, 90.0);
                                          final positive = savings >= 0;
                                          return Expanded(
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.end,
                                              children: [
                                                Text(
                                                  _money.format(savings),
                                                  style: TextStyle(
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.w700,
                                                    color: positive
                                                        ? Colors.green
                                                        : Colors.red,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 4,
                                                      ),
                                                  child: Container(
                                                    height: h,
                                                    decoration: BoxDecoration(
                                                      gradient: LinearGradient(
                                                        colors: positive
                                                            ? [
                                                                Colors.green
                                                                    .withValues(
                                                                      alpha:
                                                                          0.6,
                                                                    ),
                                                                Colors.green,
                                                              ]
                                                            : [
                                                                Colors.red
                                                                    .withValues(
                                                                      alpha:
                                                                          0.6,
                                                                    ),
                                                                Colors.red,
                                                              ],
                                                        begin: Alignment
                                                            .bottomCenter,
                                                        end:
                                                            Alignment.topCenter,
                                                      ),
                                                      borderRadius:
                                                          const BorderRadius.vertical(
                                                            top:
                                                                Radius.circular(
                                                                  5,
                                                                ),
                                                          ),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  d['period'] as String,
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.black
                                                        .withValues(alpha: 0.5),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 14),
                                GlassCard(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Category Spending (6 Months)',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      if (categoryTrends.isEmpty)
                                        const Text(
                                          'No approved expenses found for category trends.',
                                        ),
                                      ...categoryTrends.map(
                                        (cat) => _CategoryTrendRow(
                                          cat: cat,
                                          money: _money,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 14),
                                GlassCard(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Trend Insights',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      ...insights.map(
                                        (insight) =>
                                            _InsightCard(data: insight),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class _KpiTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _KpiTile({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: Colors.black.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
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
          width: 9,
          height: 9,
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

class _CategoryTrendRow extends StatelessWidget {
  final Map<String, dynamic> cat;
  final NumberFormat money;

  const _CategoryTrendRow({required this.cat, required this.money});

  @override
  Widget build(BuildContext context) {
    final data = cat['data'] as List<double>;
    final color = cat['color'] as Color;
    final max = data.fold<double>(0, (a, b) => a > b ? a : b);
    final latest = data.isEmpty ? 0.0 : data.last;
    final prev = data.length < 2 ? latest : data[data.length - 2];
    final isUp = latest >= prev;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  cat['name'] as String,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(
                isUp ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                size: 14,
                color: isUp ? Colors.red : Colors.green,
              ),
              const SizedBox(width: 4),
              Text(
                money.format(latest),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isUp ? Colors.red : Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: data.map((v) {
              final h = max <= 0 ? 4.0 : ((v / max) * 28).clamp(4.0, 28.0);
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1.5),
                  child: Container(
                    height: h,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.7),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(3),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _InsightCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final color = data['color'] as Color;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(data['icon'] as IconData, size: 16, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data['title'] as String,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  data['desc'] as String,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.black.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
