import 'package:flutter/material.dart';

import 'package:money_tracking_app/model/category_model.dart';
import 'package:money_tracking_app/controller/services/category_service.dart';
import 'package:money_tracking_app/view/utils/app_colors.dart';
import 'package:money_tracking_app/view/widgets/app_gradient_background.dart';
import 'package:money_tracking_app/view/widgets/glass_card.dart';

class AdminCategoryManagementPage extends StatefulWidget {
  const AdminCategoryManagementPage({super.key});

  @override
  State<AdminCategoryManagementPage> createState() =>
      _AdminCategoryManagementPageState();
}

class _AdminCategoryManagementPageState
    extends State<AdminCategoryManagementPage> {
  final _categoryService = CategoryService();
  final _categoryController = TextEditingController();
  final _searchController = TextEditingController();
  String _selectedCategoryType = 'expense';
  String _listTypeFilter = 'all';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _categoryController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _showCategoryDialog({CategoryModel? category}) {
    final isEditing = category != null;
    _categoryController.text = category?.name ?? '';
    _selectedCategoryType = _normalizeCategoryType(category?.type);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            isEditing ? 'Edit Category' : 'Add Category',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _categoryController,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  hintText: 'Category name',
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _selectedCategoryType,
                decoration: InputDecoration(
                  labelText: 'Category Type',
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                items: const [
                  DropdownMenuItem(value: 'expense', child: Text('Expense')),
                  DropdownMenuItem(value: 'income', child: Text('Income')),
                  DropdownMenuItem(value: 'both', child: Text('Both')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setDialogState(() => _selectedCategoryType = value);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.walletAccent,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final name = _categoryController.text.trim();
                if (name.isEmpty) return;

                if (isEditing) {
                  await _categoryService.updateCategory(
                    category.id,
                    name: name,
                    type: _selectedCategoryType,
                  );
                } else {
                  await _categoryService.addCategory(
                    name,
                    type: _selectedCategoryType,
                  );
                }

                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text(isEditing ? 'Save' : 'Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteCategory(CategoryModel category) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete Category',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: Text('Delete "${category.name}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              await _categoryService.deleteCategory(category.id);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  String _normalizeCategoryType(String? type) {
    switch (type) {
      case 'income':
      case 'both':
      case 'expense':
        return type!;
      default:
        return 'expense';
    }
  }

  String _formatCategoryType(String type) {
    switch (type) {
      case 'income':
        return 'Income';
      case 'both':
        return 'Income & Expense';
      case '':
        return 'Type not set';
      default:
        return 'Expense';
    }
  }

  bool _matchesTypeFilter(String type) {
    final normalized = _normalizeCategoryType(type);
    switch (_listTypeFilter) {
      case 'income':
        return normalized == 'income' || normalized == 'both';
      case 'expense':
        return normalized == 'expense' || normalized == 'both';
      default:
        return true;
    }
  }

  List<CategoryModel> _applyCategoryFilters(List<CategoryModel> categories) {
    final filtered = categories.where((category) {
      final nameMatches =
          _searchQuery.isEmpty ||
          category.name.toLowerCase().contains(_searchQuery);
      final typeMatches = _matchesTypeFilter(category.type);
      return nameMatches && typeMatches;
    }).toList();

    filtered.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppGradientBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'Category Management',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    GlassCard(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Manage Categories',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: _showCategoryDialog,
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Add'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.walletAccent,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'Search categories',
                              prefixIcon: const Icon(Icons.search_rounded),
                              filled: true,
                              fillColor: Colors.white.withValues(alpha: 0.72),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            children: [
                              _TypeFilterChip(
                                label: 'All',
                                selected: _listTypeFilter == 'all',
                                onTap: () =>
                                    setState(() => _listTypeFilter = 'all'),
                              ),
                              _TypeFilterChip(
                                label: 'Expense',
                                selected: _listTypeFilter == 'expense',
                                onTap: () =>
                                    setState(() => _listTypeFilter = 'expense'),
                              ),
                              _TypeFilterChip(
                                label: 'Income',
                                selected: _listTypeFilter == 'income',
                                onTap: () =>
                                    setState(() => _listTypeFilter = 'income'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    GlassCard(
                      child: StreamBuilder<List<CategoryModel>>(
                        stream: _categoryService.getCategories(),
                        builder: (context, catSnap) {
                          if (catSnap.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          final categories = _applyCategoryFilters(
                            catSnap.data ?? [],
                          );
                          if (categories.isEmpty) {
                            return Text(
                              _searchQuery.isNotEmpty ||
                                      _listTypeFilter != 'all'
                                  ? 'No categories match your search/filter.'
                                  : 'No categories yet. Tap Add to create one.',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.black54,
                              ),
                            );
                          }

                          return ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: categories.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, i) {
                              final cat = categories[i];
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.55),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(7),
                                      decoration: BoxDecoration(
                                        color: AppColors.walletAccent
                                            .withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.label_rounded,
                                        size: 16,
                                        color: AppColors.walletAccent,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            cat.name,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            _formatCategoryType(cat.type),
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.black.withValues(
                                                alpha: 0.55,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.edit_outlined,
                                        color: AppColors.walletAccent,
                                        size: 20,
                                      ),
                                      onPressed: () =>
                                          _showCategoryDialog(category: cat),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                    const SizedBox(width: 10),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline_rounded,
                                        color: Colors.red,
                                        size: 20,
                                      ),
                                      onPressed: () =>
                                          _confirmDeleteCategory(cat),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
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
          ),
        ),
      ),
    );
  }
}

class _TypeFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TypeFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.walletAccent.withValues(alpha: 0.18),
      labelStyle: TextStyle(
        color: selected ? AppColors.walletAccent : Colors.black87,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}
