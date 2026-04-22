import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:money_tracking_app/view/widgets/glass_card.dart';
import 'package:money_tracking_app/view/widgets/app_gradient_background.dart';
import 'package:money_tracking_app/view/utils/app_colors.dart';
import 'package:money_tracking_app/model/category_model.dart';
import 'package:money_tracking_app/controller/services/budget_service.dart';
import 'package:money_tracking_app/controller/services/category_service.dart';
import 'export_report_page.dart';
import 'email_summary_page.dart';
import 'set_budget_page.dart';
import 'spending_trends_page.dart';

class BudgetReportsPanelScreen extends StatefulWidget {
  const BudgetReportsPanelScreen({super.key});

  @override
  State<BudgetReportsPanelScreen> createState() =>
      _BudgetReportsPanelScreenState();
}

class _BudgetReportsPanelScreenState extends State<BudgetReportsPanelScreen> {
  _BudgetReportsPanelScreenState()
    : selectedMonth = DateTime.now().month - 1,
      selectedYear = DateTime.now().year;

  final BudgetService _budgetService = BudgetService();
  final CategoryService _categoryService = CategoryService();
  bool _sentCurrentMonthReminder = false;
  int selectedMonth;
  int selectedYear;
  final List<String> months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  final List<Color> categoryColors = [
    const Color(0xFFFF6B6B),
    const Color(0xFF4ECDC4),
    const Color(0xFFFFE66D),
    const Color(0xFF95E1D3),
    const Color(0xFFC7CEEA),
  ];

  List<int> get years {
    final now = DateTime.now().year;
    return List<int>.generate(6, (index) => now - 4 + index);
  }

  DateTime get _activeMonth => DateTime(selectedYear, selectedMonth + 1, 1);

  String _money(double value) => 'â‚¹${value.toStringAsFixed(0)}';

  Color _categoryColor(int index) =>
      categoryColors[index % categoryColors.length];

  List<String> _combineCategories(
    List<CategoryModel> activeCategories,
    Map<String, double> budgetData,
    Map<String, double> spentData,
  ) {
    final all = <String>{
      ...activeCategories.map((category) => category.name),
      ...budgetData.keys,
      ...spentData.keys,
    };

    final sorted = all.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return sorted;
  }

  double _maxBarY(
    List<String> categories,
    Map<String, double> budgetData,
    Map<String, double> spentData,
  ) {
    var maxValue = 0.0;
    for (final category in categories) {
      final budget = budgetData[category] ?? 0;
      final spent = spentData[category] ?? 0;
      maxValue = maxValue < budget ? budget : maxValue;
      maxValue = maxValue < spent ? spent : maxValue;
    }

    if (maxValue <= 0) {
      return 100;
    }

    return maxValue * 1.2;
  }

  @override
  void initState() {
    super.initState();
    _trySendCurrentMonthReminder();
  }

  Future<void> _trySendCurrentMonthReminder() async {
    if (_sentCurrentMonthReminder) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.trim().isEmpty) return;

    _sentCurrentMonthReminder = true;
    await _budgetService.maybeSendNewMonthReminder(uid: uid);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppGradientBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                Text(
                  'Budget & Reports',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List.generate(
                      months.length,
                      (index) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: InkWell(
                          onTap: () {
                            setState(() => selectedMonth = index);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: selectedMonth == index
                                  ? AppColors.walletAccent
                                  : Colors.white.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              months[index],
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: selectedMonth == index
                                    ? Colors.white
                                    : Colors.black,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(
                      'Year',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.black.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: selectedYear,
                          items: years
                              .map(
                                (year) => DropdownMenuItem<int>(
                                  value: year,
                                  child: Text(
                                    '$year',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() => selectedYear = value);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildDynamicReports(context),
                const SizedBox(height: 16),
                _buildQuickReportActions(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickReportActions(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final periodLabel = '${months[selectedMonth]} $selectedYear';

    if (currentUser == null) {
      return GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quick Report Actions',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            _ReportAction(
              icon: Icons.download_rounded,
              title: 'Export Report',
              subtitle: 'Sign in to load Firestore data',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ExportReportPage(initialMonth: _activeMonth),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return StreamBuilder<List<CategoryModel>>(
      stream: _categoryService.getActiveCategories(type: 'expense'),
      builder: (context, categorySnapshot) {
        if (categorySnapshot.hasError) {
          return GlassCard(
            child: Text(
              'Failed to load categories: ${categorySnapshot.error}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          );
        }

        final categories = categorySnapshot.data ?? const <CategoryModel>[];

        return StreamBuilder<Map<String, double>>(
          stream: _budgetService.streamCategoryBudgets(
            uid: currentUser.uid,
            month: _activeMonth,
          ),
          builder: (context, budgetSnapshot) {
            if (budgetSnapshot.hasError) {
              return GlassCard(
                child: Text(
                  'Failed to load budgets: ${budgetSnapshot.error}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              );
            }

            final budgetData = budgetSnapshot.data ?? const <String, double>{};

            return StreamBuilder<Map<String, double>>(
              stream: _budgetService.streamMonthlyExpenseByCategory(
                uid: currentUser.uid,
                month: _activeMonth,
              ),
              builder: (context, spentSnapshot) {
                if (spentSnapshot.hasError) {
                  return GlassCard(
                    child: Text(
                      'Failed to load transactions: ${spentSnapshot.error}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  );
                }

                final spentData =
                    spentSnapshot.data ?? const <String, double>{};
                final categoryNames = _combineCategories(
                  categories,
                  budgetData,
                  spentData,
                );

                final totalBudget = budgetData.values.fold<double>(
                  0,
                  (sum, amount) => sum + amount,
                );
                final totalSpent = spentData.values.fold<double>(
                  0,
                  (sum, amount) => sum + amount,
                );

                String topCategoryText = 'No spending yet';
                if (spentData.isNotEmpty) {
                  final topEntry = spentData.entries.reduce(
                    (a, b) => a.value >= b.value ? a : b,
                  );
                  topCategoryText =
                      'Top: ${topEntry.key} (${_money(topEntry.value)})';
                }

                final configuredBudgetCount = budgetData.values
                    .where((value) => value > 0)
                    .length;

                return GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Quick Report Actions',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _ReportAction(
                        icon: Icons.download_rounded,
                        title: 'Export Report',
                        subtitle:
                            '$periodLabel â€¢ ${categoryNames.length} categories',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                ExportReportPage(initialMonth: _activeMonth),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _ReportAction(
                        icon: Icons.email_rounded,
                        title: 'Email Summary',
                        subtitle:
                            '${_money(totalSpent)} spent of ${_money(totalBudget)}',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const EmailSummaryPage(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _ReportAction(
                        icon: Icons.tune_rounded,
                        title: 'Set Budget',
                        subtitle:
                            '$configuredBudgetCount categories have budget',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                SetBudgetPage(initialMonth: _activeMonth),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _ReportAction(
                        icon: Icons.show_chart_rounded,
                        title: 'Spending Trends',
                        subtitle: topCategoryText,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SpendingTrendsPage(),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildDynamicReports(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const GlassCard(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: Text(
              'Sign in to view your budget and reports.',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
      );
    }

    return StreamBuilder<List<CategoryModel>>(
      stream: _categoryService.getActiveCategories(type: 'expense'),
      builder: (context, categorySnapshot) {
        if (categorySnapshot.hasError) {
          return GlassCard(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'Failed to load categories: ${categorySnapshot.error}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          );
        }

        final categories = categorySnapshot.data ?? const <CategoryModel>[];

        return StreamBuilder<Map<String, double>>(
          stream: _budgetService.streamCategoryBudgets(
            uid: currentUser.uid,
            month: _activeMonth,
          ),
          builder: (context, budgetSnapshot) {
            if (budgetSnapshot.hasError) {
              return GlassCard(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'Failed to load budgets: ${budgetSnapshot.error}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              );
            }

            final budgetData = budgetSnapshot.data ?? const <String, double>{};

            return StreamBuilder<Map<String, double>>(
              stream: _budgetService.streamMonthlyExpenseByCategory(
                uid: currentUser.uid,
                month: _activeMonth,
              ),
              builder: (context, spentSnapshot) {
                if (spentSnapshot.hasError) {
                  return GlassCard(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          'Failed to load transactions: ${spentSnapshot.error}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  );
                }

                if (categorySnapshot.connectionState ==
                        ConnectionState.waiting ||
                    budgetSnapshot.connectionState == ConnectionState.waiting ||
                    spentSnapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final spentData =
                    spentSnapshot.data ?? const <String, double>{};
                final categoryNames = _combineCategories(
                  categories,
                  budgetData,
                  spentData,
                );

                final totalBudget = budgetData.values.fold<double>(
                  0,
                  (sum, amount) => sum + amount,
                );
                final totalSpent = spentData.values.fold<double>(
                  0,
                  (sum, amount) => sum + amount,
                );
                final remaining = totalBudget - totalSpent;

                if (categoryNames.isEmpty) {
                  return const GlassCard(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          'No category or transaction data for this month yet.',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  );
                }

                return Column(
                  children: [
                    GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Monthly Summary',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  children: [
                                    Text(
                                      'Budget',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black.withValues(
                                          alpha: 0.65,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _money(totalBudget),
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.green,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  children: [
                                    Text(
                                      'Spent',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black.withValues(
                                          alpha: 0.65,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _money(totalSpent),
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.orange,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  children: [
                                    Text(
                                      'Remaining',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black.withValues(
                                          alpha: 0.65,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _money(remaining),
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900,
                                        color: remaining >= 0
                                            ? Colors.blue
                                            : Colors.red,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (totalBudget <= 0) ...[
                            const SizedBox(height: 12),
                            const Text(
                              'Set Budget to start tracking monthly limits.',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Expense Breakdown (Pie Chart)',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 250,
                            child: PieChart(
                              PieChartData(
                                sections: _getPieChartSections(
                                  categoryNames,
                                  spentData,
                                ),
                                centerSpaceRadius: 50,
                                sectionsSpace: 2,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            children: List.generate(categoryNames.length, (
                              index,
                            ) {
                              final category = categoryNames[index];
                              final spent = spentData[category] ?? 0;
                              return Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: _categoryColor(index),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '$category: ${_money(spent)}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              );
                            }),
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
                            'Budget vs Spent (Bar Chart)',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 280,
                            child: BarChart(
                              BarChartData(
                                alignment: BarChartAlignment.spaceAround,
                                maxY: _maxBarY(
                                  categoryNames,
                                  budgetData,
                                  spentData,
                                ),
                                barTouchData: BarTouchData(enabled: true),
                                titlesData: FlTitlesData(
                                  show: true,
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      getTitlesWidget: (value, meta) {
                                        if (value.toInt() <
                                            categoryNames.length) {
                                          return Text(
                                            categoryNames[value.toInt()],
                                            style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          );
                                        }
                                        return const Text('');
                                      },
                                    ),
                                  ),
                                  leftTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      getTitlesWidget: (value, meta) {
                                        return Text(
                                          'â‚¹${value.toInt()}',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                barGroups: _getBarChartGroups(
                                  categoryNames,
                                  budgetData,
                                  spentData,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              _ChartLegendItem(
                                color: Colors.green,
                                label: 'Budget',
                              ),
                              SizedBox(width: 24),
                              _ChartLegendItem(
                                color: Colors.orange,
                                label: 'Spent',
                              ),
                            ],
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
                            'Budget by Category',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 14),
                          ...categoryNames.map((category) {
                            final budget = budgetData[category] ?? 0;
                            final spent = spentData[category] ?? 0;
                            final percentage = budget <= 0
                                ? (spent > 0 ? 100.0 : 0.0)
                                : (spent / budget * 100).clamp(0, 100);

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        category,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      Text(
                                        '${percentage.toStringAsFixed(0)}%',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: percentage > 80
                                              ? Colors.red
                                              : Colors.green,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: LinearProgressIndicator(
                                      value: percentage / 100,
                                      minHeight: 6,
                                      backgroundColor: Colors.white.withValues(
                                        alpha: 0.5,
                                      ),
                                      valueColor: AlwaysStoppedAnimation(
                                        percentage > 80
                                            ? Colors.red
                                            : Colors.green,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${_money(spent)} / ${_money(budget)}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.black.withValues(
                                        alpha: 0.6,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  List<PieChartSectionData> _getPieChartSections(
    List<String> categories,
    Map<String, double> spentData,
  ) {
    final total = spentData.values.fold<double>(0, (sum, val) => sum + val);

    if (total <= 0) {
      return [
        PieChartSectionData(
          color: Colors.grey.shade300,
          value: 1,
          title: '0%',
          radius: 50,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.black54,
          ),
        ),
      ];
    }

    return List.generate(categories.length, (index) {
      final category = categories[index];
      final spent = spentData[category] ?? 0;
      final percentage = (spent / total) * 100;

      return PieChartSectionData(
        color: _categoryColor(index),
        value: spent,
        title: '${percentage.toStringAsFixed(0)}%',
        radius: 50,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      );
    });
  }

  List<BarChartGroupData> _getBarChartGroups(
    List<String> categories,
    Map<String, double> budgetData,
    Map<String, double> spentData,
  ) {
    return List.generate(categories.length, (index) {
      final category = categories[index];
      final budget = budgetData[category] ?? 0.0;
      final spent = spentData[category] ?? 0.0;

      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(toY: budget, color: Colors.green, width: 12),
          BarChartRodData(toY: spent, color: Colors.orange, width: 12),
        ],
      );
    });
  }
}

class _ChartLegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _ChartLegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _ReportAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _ReportAction({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.walletAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.walletAccent, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Colors.black.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_rounded,
              size: 18,
              color: AppColors.walletAccent,
            ),
          ],
        ),
      ),
    );
  }
}
