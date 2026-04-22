import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:money_tracking_app/model/category_model.dart';
import 'package:money_tracking_app/controller/services/category_service.dart';
import 'package:money_tracking_app/controller/services/firestore_service.dart';
import 'package:money_tracking_app/view/utils/app_colors.dart';
import 'package:money_tracking_app/view/utils/app_input_decorations.dart';
import 'package:money_tracking_app/view/utils/category_ui.dart';
import 'package:money_tracking_app/view/widgets/app_gradient_background.dart';
import 'package:money_tracking_app/view/widgets/glass_card.dart';

class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _service = FirestoreService();
  final _categoryService = CategoryService();
  final _formKey = GlobalKey<FormState>();

  final _amount = TextEditingController();
  final _note = TextEditingController();

  String _type = "expense";
  String? _category;
  bool _saving = false;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  double? _parseAmount(String input) {
    final sanitized = input.replaceAll(',', '').replaceAll(' ', '').trim();
    if (sanitized.isEmpty) return null;
    return double.tryParse(sanitized);
  }

  @override
  Widget build(BuildContext context) {
    final isIncome = _type == "income";
    final accent = isIncome ? Colors.green : Colors.red;

    return Scaffold(
      body: AppGradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GlassCard(
                  child: Row(
                    children: [
                      InkWell(
                        onTap: () => Navigator.pop(context),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.arrow_back_rounded),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Add Transaction",
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              "Track your money smartly",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color:
                              (isIncome
                                      ? AppColors.incomeChipBg
                                      : AppColors.expenseChipBg)
                                  .withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          isIncome
                              ? Icons.trending_up_rounded
                              : Icons.trending_down_rounded,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: StreamBuilder<List<CategoryModel>>(
                  stream: _categoryService.getActiveCategories(type: _type),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }

                    final allCategories = snapshot.data ?? [];

                    if (allCategories.isNotEmpty &&
                        (_category == null ||
                            !allCategories.any((e) => e.name == _category))) {
                      _category = allCategories.first.name;
                    }

                    return LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: constraints.maxHeight - 18,
                            ),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                children: [
                                  GlassCard(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          "Type",
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: _typeChip(
                                                label: "Expense",
                                                icon: Icons
                                                    .remove_circle_outline_rounded,
                                                selected: _type == "expense",
                                                bg: AppColors.expenseChipBg,
                                                border: Colors.red,
                                                onTap: () {
                                                  setState(() {
                                                    _type = "expense";
                                                    _category = null;
                                                  });
                                                },
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: _typeChip(
                                                label: "Income",
                                                icon: Icons
                                                    .add_circle_outline_rounded,
                                                selected: _type == "income",
                                                bg: AppColors.incomeChipBg,
                                                border: Colors.green,
                                                onTap: () {
                                                  setState(() {
                                                    _type = "income";
                                                    _category = null;
                                                  });
                                                },
                                              ),
                                            ),
                                          ],
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
                                          "Amount",
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        TextFormField(
                                          controller: _amount,
                                          keyboardType:
                                              const TextInputType.numberWithOptions(
                                                decimal: true,
                                              ),
                                          decoration:
                                              AppInputDecorations.filled(
                                                hintText: "Enter amount",
                                                prefixIcon: const Icon(
                                                  Icons.currency_rupee_rounded,
                                                ),
                                              ),
                                          validator: (v) {
                                            if (v == null || v.trim().isEmpty) {
                                              return "Enter amount";
                                            }
                                            final n = _parseAmount(v);
                                            if (n == null) {
                                              return "Enter valid number";
                                            }
                                            if (n <= 0) {
                                              return "Amount must be > 0";
                                            }
                                            return null;
                                          },
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
                                          "Category",
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        if (allCategories.isEmpty)
                                          Text(
                                            _type == 'income'
                                                ? 'No income category found'
                                                : 'No expense category found',
                                            style: const TextStyle(
                                              color: Colors.black54,
                                            ),
                                          )
                                        else
                                          Row(
                                            children: [
                                              Container(
                                                width: 52,
                                                height: 52,
                                                decoration: BoxDecoration(
                                                  color:
                                                      (CategoryUi.iconBg[_category] ??
                                                              const Color(
                                                                0xFFF5F5F5,
                                                              ))
                                                          .withValues(
                                                            alpha: 0.95,
                                                          ),
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                ),
                                                child: Icon(
                                                  CategoryUi.iconFor(
                                                    _category ?? 'Other',
                                                  ),
                                                  size: 28,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: DropdownButtonFormField<String>(
                                                  initialValue: _category,
                                                  isExpanded: true,
                                                  icon: const Icon(
                                                    Icons
                                                        .keyboard_arrow_down_rounded,
                                                  ),
                                                  items: allCategories
                                                      .map(
                                                        (c) => DropdownMenuItem(
                                                          value: c.name,
                                                          child: Text(c.name),
                                                        ),
                                                      )
                                                      .toList(),
                                                  onChanged: (v) => setState(
                                                    () => _category = v,
                                                  ),
                                                  decoration:
                                                      AppInputDecorations.filled(),
                                                ),
                                              ),
                                            ],
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
                                          "Note (optional)",
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        TextFormField(
                                          controller: _note,
                                          maxLines: 2,
                                          decoration:
                                              AppInputDecorations.filled(
                                                hintText: "Write somethingâ€¦",
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 56,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: accent.withValues(
                                          alpha: 0.90,
                                        ),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
                                        ),
                                        elevation: 0,
                                      ),
                                      onPressed: () async {
                                        final messenger =
                                            ScaffoldMessenger.maybeOf(context);
                                        final navigator = Navigator.of(context);

                                        if (_saving) return;
                                        if (!_formKey.currentState!
                                            .validate()) {
                                          return;
                                        }
                                        if (_category == null) {
                                          messenger?.showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                "Please select category",
                                              ),
                                            ),
                                          );
                                          return;
                                        }

                                        final currentUser =
                                            FirebaseAuth.instance.currentUser;
                                        if (currentUser == null) {
                                          if (!mounted) return;
                                          messenger?.showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Please login again to add a transaction',
                                              ),
                                            ),
                                          );
                                          return;
                                        }

                                        final amount = _parseAmount(
                                          _amount.text,
                                        );
                                        if (amount == null || amount <= 0) {
                                          messenger?.showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Enter a valid amount',
                                              ),
                                            ),
                                          );
                                          return;
                                        }

                                        setState(() => _saving = true);
                                        try {
                                          await _service.addTransaction(
                                            userId: currentUser.uid,
                                            amount: amount,
                                            type: _type,
                                            category: _category!,
                                            note: _note.text.trim(),
                                          );

                                          if (!mounted) return;
                                          if (navigator.mounted) {
                                            navigator.pop(true);
                                          }
                                        } catch (e) {
                                          if (!mounted) return;
                                          messenger?.showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Failed to save transaction: $e',
                                              ),
                                            ),
                                          );
                                        } finally {
                                          if (mounted) {
                                            setState(() => _saving = false);
                                          }
                                        }
                                      },
                                      child: Text(
                                        _saving
                                            ? 'Saving...'
                                            : (isIncome
                                                  ? "Save Income"
                                                  : "Save Expense"),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
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

  Widget _typeChip({
    required String label,
    required IconData icon,
    required bool selected,
    required Color bg,
    required Color border,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: selected
              ? bg.withValues(alpha: 0.95)
              : Colors.white.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? border.withValues(alpha: 0.8)
                : Colors.transparent,
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: selected ? border : Colors.black54),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: selected ? border : const Color(0xFF1F2A44),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
