import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:money_tracking_app/view/widgets/app_gradient_background.dart';
import 'package:money_tracking_app/view/widgets/glass_card.dart';
import 'package:money_tracking_app/view/utils/app_colors.dart';
import 'package:money_tracking_app/model/category_model.dart';
import 'package:money_tracking_app/controller/services/budget_service.dart';
import 'package:money_tracking_app/controller/services/category_service.dart';

class SetBudgetPage extends StatefulWidget {
  const SetBudgetPage({super.key, this.initialMonth});

  final DateTime? initialMonth;

  @override
  State<SetBudgetPage> createState() => _SetBudgetPageState();
}

class _SetBudgetPageState extends State<SetBudgetPage> {
  _SetBudgetPageState()
    : _selectedMonth = DateTime.now().month - 1,
      _selectedYear = DateTime.now().year;

  final BudgetService _budgetService = BudgetService();
  final CategoryService _categoryService = CategoryService();

  int _selectedMonth;
  int _selectedYear;
  bool _isSaving = false;

  final List<String> _months = const [
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

  List<int> get _years {
    final now = DateTime.now().year;
    return List<int>.generate(6, (index) => now - 4 + index);
  }

  @override
  void initState() {
    super.initState();
    final initial = widget.initialMonth;
    if (initial != null) {
      _selectedMonth = initial.month - 1;
      _selectedYear = initial.year;
    }
  }

  DateTime get _activeMonth => DateTime(_selectedYear, _selectedMonth + 1, 1);

  String _money(double value) => 'â‚¹${value.toStringAsFixed(0)}';

  IconData _iconForCategory(String name) {
    final key = name.toLowerCase();
    if (key.contains('food') ||
        key.contains('meal') ||
        key.contains('grocery')) {
      return Icons.restaurant_rounded;
    }
    if (key.contains('transport') ||
        key.contains('travel') ||
        key.contains('fuel')) {
      return Icons.directions_car_rounded;
    }
    if (key.contains('shop')) {
      return Icons.shopping_bag_rounded;
    }
    if (key.contains('entertain')) {
      return Icons.movie_rounded;
    }
    if (key.contains('health') || key.contains('medical')) {
      return Icons.favorite_rounded;
    }
    if (key.contains('utilit') || key.contains('bill')) {
      return Icons.bolt_rounded;
    }
    if (key.contains('educat')) {
      return Icons.school_rounded;
    }
    return Icons.category_rounded;
  }

  Color _colorForCategory(String name) {
    final palette = <Color>[
      const Color(0xFFFF6B6B),
      const Color(0xFF4ECDC4),
      const Color(0xFFFFE66D),
      const Color(0xFF95E1D3),
      const Color(0xFFC7CEEA),
      Colors.pink,
      Colors.blue,
    ];

    final idx = name.toLowerCase().codeUnits.fold<int>(
      0,
      (sum, code) => sum + code,
    );
    return palette[idx % palette.length];
  }

  Future<void> _editBudget({
    required String uid,
    required String category,
    required double currentBudget,
    required Color color,
    required IconData icon,
  }) async {
    final controller = TextEditingController(
      text: currentBudget.toStringAsFixed(0),
    );

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Text(category, style: const TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Set monthly budget',
              style: TextStyle(
                fontSize: 12,
                color: Colors.black.withValues(alpha: 0.55),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                prefixText: 'â‚¹ ',
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                hintText: '0',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _isSaving
                ? null
                : () async {
                    final value = double.tryParse(controller.text.trim());
                    if (value != null && value >= 0) {
                      setState(() => _isSaving = true);
                      try {
                        await _budgetService.setCategoryBudget(
                          uid: uid,
                          month: _activeMonth,
                          category: category,
                          amount: value,
                        );
                      } finally {
                        if (mounted) {
                          setState(() => _isSaving = false);
                        }
                      }
                    }
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.walletAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _resetAll(String uid, List<String> categories) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Reset Budgets',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: const Text(
          'This will reset all category budgets for the selected month to 0.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _isSaving
                ? null
                : () async {
                    setState(() => _isSaving = true);
                    try {
                      await _budgetService.resetCategoryBudgets(
                        uid: uid,
                        month: _activeMonth,
                        categories: categories,
                      );
                    } finally {
                      if (mounted) {
                        setState(() => _isSaving = false);
                      }
                    }

                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
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
                    'Please sign in to manage category budgets.',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                )
              : StreamBuilder<List<CategoryModel>>(
                  stream: _categoryService.getActiveCategories(type: 'expense'),
                  builder: (context, categorySnapshot) {
                    final activeCategories =
                        categorySnapshot.data ?? const <CategoryModel>[];

                    return StreamBuilder<Map<String, double>>(
                      stream: _budgetService.streamCategoryBudgets(
                        uid: currentUser.uid,
                        month: _activeMonth,
                      ),
                      builder: (context, budgetSnapshot) {
                        final budgetData =
                            budgetSnapshot.data ?? const <String, double>{};

                        return StreamBuilder<Map<String, double>>(
                          stream: _budgetService.streamMonthlyExpenseByCategory(
                            uid: currentUser.uid,
                            month: _activeMonth,
                          ),
                          builder: (context, spentSnapshot) {
                            if (categorySnapshot.connectionState ==
                                    ConnectionState.waiting ||
                                budgetSnapshot.connectionState ==
                                    ConnectionState.waiting ||
                                spentSnapshot.connectionState ==
                                    ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }

                            final spentData =
                                spentSnapshot.data ?? const <String, double>{};
                            final categoryNames =
                                <String>{
                                  ...activeCategories.map(
                                    (category) => category.name,
                                  ),
                                  ...budgetData.keys,
                                  ...spentData.keys,
                                }.toList()..sort(
                                  (a, b) => a.toLowerCase().compareTo(
                                    b.toLowerCase(),
                                  ),
                                );

                            final totalBudget = budgetData.values.fold<double>(
                              0,
                              (sum, amount) => sum + amount,
                            );
                            final totalSpent = spentData.values.fold<double>(
                              0,
                              (sum, amount) => sum + amount,
                            );
                            final usagePercent = totalBudget <= 0
                                ? (totalSpent > 0 ? 100.0 : 0.0)
                                : (totalSpent / totalBudget * 100).clamp(
                                    0,
                                    100,
                                  );

                            return Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    12,
                                    16,
                                    0,
                                  ),
                                  child: Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(
                                          Icons.arrow_back_rounded,
                                        ),
                                        onPressed: () => Navigator.pop(context),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                      const SizedBox(width: 12),
                                      const Expanded(
                                        child: Text(
                                          'Set Budget',
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                      TextButton.icon(
                                        onPressed: _isSaving
                                            ? null
                                            : () => _resetAll(
                                                currentUser.uid,
                                                categoryNames,
                                              ),
                                        icon: const Icon(
                                          Icons.refresh_rounded,
                                          size: 16,
                                        ),
                                        label: const Text('Reset'),
                                        style: TextButton.styleFrom(
                                          foregroundColor: Colors.red,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 10),
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  child: Row(
                                    children: List.generate(_months.length, (
                                      index,
                                    ) {
                                      final isSelected =
                                          index == _selectedMonth;
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          right: 8,
                                        ),
                                        child: InkWell(
                                          onTap: () => setState(
                                            () => _selectedMonth = index,
                                          ),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 8,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isSelected
                                                  ? AppColors.walletAccent
                                                  : Colors.white.withValues(
                                                      alpha: 0.6,
                                                    ),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              _months[index],
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: isSelected
                                                    ? Colors.white
                                                    : Colors.black,
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    }),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  child: Row(
                                    children: [
                                      Text(
                                        'Year',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.black.withValues(
                                            alpha: 0.7,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(
                                            alpha: 0.6,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                        ),
                                        child: DropdownButtonHideUnderline(
                                          child: DropdownButton<int>(
                                            value: _selectedYear,
                                            items: _years
                                                .map(
                                                  (
                                                    year,
                                                  ) => DropdownMenuItem<int>(
                                                    value: year,
                                                    child: Text(
                                                      '$year',
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                    ),
                                                  ),
                                                )
                                                .toList(),
                                            onChanged: (value) {
                                              if (value == null) return;
                                              setState(
                                                () => _selectedYear = value,
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  child: GlassCard(
                                    child: Row(
                                      children: [
                                        _TotalStat(
                                          label: 'Total Budget',
                                          value: _money(totalBudget),
                                          color: AppColors.walletAccent,
                                          icon: Icons
                                              .account_balance_wallet_rounded,
                                        ),
                                        Container(
                                          height: 40,
                                          width: 1,
                                          color: Colors.black.withValues(
                                            alpha: 0.08,
                                          ),
                                        ),
                                        _TotalStat(
                                          label: 'Total Spent',
                                          value: _money(totalSpent),
                                          color: Colors.orange,
                                          icon: Icons.payments_rounded,
                                        ),
                                        Container(
                                          height: 40,
                                          width: 1,
                                          color: Colors.black.withValues(
                                            alpha: 0.08,
                                          ),
                                        ),
                                        _TotalStat(
                                          label: 'Remaining',
                                          value: _money(
                                            totalBudget - totalSpent,
                                          ),
                                          color: totalBudget - totalSpent >= 0
                                              ? Colors.green
                                              : Colors.red,
                                          icon: Icons.savings_rounded,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text(
                                            'Overall Budget Usage',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          Text(
                                            '${usagePercent.toStringAsFixed(0)}%',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: totalSpent > totalBudget
                                                  ? Colors.red
                                                  : AppColors.walletAccent,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: LinearProgressIndicator(
                                          value: (usagePercent / 100).clamp(
                                            0.0,
                                            1.0,
                                          ),
                                          minHeight: 8,
                                          backgroundColor: Colors.black
                                              .withValues(alpha: 0.08),
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                totalSpent > totalBudget
                                                    ? Colors.red
                                                    : AppColors.walletAccent,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Expanded(
                                  child: categoryNames.isEmpty
                                      ? const Center(
                                          child: Text(
                                            'No categories available yet.',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        )
                                      : ListView.separated(
                                          padding: const EdgeInsets.fromLTRB(
                                            16,
                                            0,
                                            16,
                                            24,
                                          ),
                                          itemCount: categoryNames.length,
                                          separatorBuilder: (_, __) =>
                                              const SizedBox(height: 10),
                                          itemBuilder: (context, i) {
                                            final category = categoryNames[i];
                                            final budget =
                                                budgetData[category] ?? 0;
                                            final spent =
                                                spentData[category] ?? 0;
                                            final progress = budget <= 0
                                                ? (spent > 0 ? 1.0 : 0.0)
                                                : (spent / budget).clamp(
                                                    0.0,
                                                    1.0,
                                                  );
                                            final isOver =
                                                budget > 0 && spent > budget;
                                            final color = _colorForCategory(
                                              category,
                                            );
                                            final icon = _iconForCategory(
                                              category,
                                            );

                                            return GlassCard(
                                              padding: const EdgeInsets.all(14),
                                              child: Column(
                                                children: [
                                                  Row(
                                                    children: [
                                                      Container(
                                                        padding:
                                                            const EdgeInsets.all(
                                                              9,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color: color
                                                              .withValues(
                                                                alpha: 0.18,
                                                              ),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                10,
                                                              ),
                                                        ),
                                                        child: Icon(
                                                          icon,
                                                          color: color,
                                                          size: 20,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 12),
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Text(
                                                              category,
                                                              style: const TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w800,
                                                                fontSize: 14,
                                                              ),
                                                            ),
                                                            Text(
                                                              'Spent ${_money(spent)} of ${_money(budget)}',
                                                              style: TextStyle(
                                                                fontSize: 11,
                                                                color: Colors
                                                                    .black
                                                                    .withValues(
                                                                      alpha:
                                                                          0.5,
                                                                    ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .end,
                                                        children: [
                                                          Text(
                                                            _money(budget),
                                                            style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w900,
                                                              fontSize: 16,
                                                              color: isOver
                                                                  ? Colors.red
                                                                  : color,
                                                            ),
                                                          ),
                                                          GestureDetector(
                                                            onTap: _isSaving
                                                                ? null
                                                                : () => _editBudget(
                                                                    uid: currentUser
                                                                        .uid,
                                                                    category:
                                                                        category,
                                                                    currentBudget:
                                                                        budget,
                                                                    color:
                                                                        color,
                                                                    icon: icon,
                                                                  ),
                                                            child: Container(
                                                              padding:
                                                                  const EdgeInsets.symmetric(
                                                                    horizontal:
                                                                        8,
                                                                    vertical: 3,
                                                                  ),
                                                              decoration: BoxDecoration(
                                                                color: AppColors
                                                                    .walletAccent
                                                                    .withValues(
                                                                      alpha:
                                                                          0.12,
                                                                    ),
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                      6,
                                                                    ),
                                                              ),
                                                              child: const Row(
                                                                mainAxisSize:
                                                                    MainAxisSize
                                                                        .min,
                                                                children: [
                                                                  Icon(
                                                                    Icons
                                                                        .edit_rounded,
                                                                    size: 11,
                                                                    color: AppColors
                                                                        .walletAccent,
                                                                  ),
                                                                  SizedBox(
                                                                    width: 3,
                                                                  ),
                                                                  Text(
                                                                    'Edit',
                                                                    style: TextStyle(
                                                                      fontSize:
                                                                          10,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w700,
                                                                      color: AppColors
                                                                          .walletAccent,
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 10),
                                                  ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          6,
                                                        ),
                                                    child: LinearProgressIndicator(
                                                      value: progress,
                                                      minHeight: 7,
                                                      backgroundColor: Colors
                                                          .black
                                                          .withValues(
                                                            alpha: 0.08,
                                                          ),
                                                      valueColor:
                                                          AlwaysStoppedAnimation<
                                                            Color
                                                          >(
                                                            isOver
                                                                ? Colors.red
                                                                : color,
                                                          ),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    children: [
                                                      Text(
                                                        '${(progress * 100).toStringAsFixed(0)}% used',
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color: Colors.black
                                                              .withValues(
                                                                alpha: 0.45,
                                                              ),
                                                        ),
                                                      ),
                                                      if (budget <= 0 &&
                                                          spent > 0)
                                                        const Text(
                                                          'No budget set',
                                                          style: TextStyle(
                                                            fontSize: 10,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            color: Colors.red,
                                                          ),
                                                        )
                                                      else if (isOver)
                                                        Text(
                                                          'Over by ${_money(spent - budget)}',
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 10,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700,
                                                                color:
                                                                    Colors.red,
                                                              ),
                                                        )
                                                      else
                                                        Text(
                                                          '${_money(budget - spent)} left',
                                                          style: TextStyle(
                                                            fontSize: 10,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color: Colors.black
                                                                .withValues(
                                                                  alpha: 0.45,
                                                                ),
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
                              ],
                            );
                          },
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

// â”€â”€ Helper Widgets â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _TotalStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _TotalStat({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.black.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}
