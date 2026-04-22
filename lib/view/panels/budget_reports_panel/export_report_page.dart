import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart' as xl;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import 'package:money_tracking_app/model/category_model.dart';
import 'package:money_tracking_app/controller/services/budget_service.dart';
import 'package:money_tracking_app/controller/services/category_service.dart';
import 'package:money_tracking_app/view/utils/app_colors.dart';
import 'package:money_tracking_app/view/widgets/app_gradient_background.dart';
import 'package:money_tracking_app/view/widgets/glass_card.dart';

class ExportReportPage extends StatefulWidget {
  const ExportReportPage({super.key, this.initialMonth});

  final DateTime? initialMonth;

  @override
  State<ExportReportPage> createState() => _ExportReportPageState();
}

class _ExportReportPageState extends State<ExportReportPage> {
  _ExportReportPageState()
    : _selectedMonth = DateTime.now().month - 1,
      _selectedYear = DateTime.now().year;

  final BudgetService _budgetService = BudgetService();
  final CategoryService _categoryService = CategoryService();

  String _selectedFormat = 'PDF';
  bool _includeCharts = true;
  bool _includeBudgetVsActual = true;
  bool _includeTransactionList = true;
  bool _includeSummary = true;
  bool _isExporting = false;

  int _selectedMonth;
  int _selectedYear;

  static const List<String> _formats = ['PDF', 'CSV', 'Excel', 'JSON'];
  static const List<String> _months = [
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

  List<int> get _years {
    final now = DateTime.now().year;
    return List<int>.generate(6, (index) => now - 4 + index);
  }

  String _money(double value) => 'â‚¹${value.toStringAsFixed(0)}';

  String get _periodLabel => '${_months[_selectedMonth]} $_selectedYear';

  String get _safePeriodLabel =>
      '${_selectedYear}_${(_selectedMonth + 1).toString().padLeft(2, '0')}';

  double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  List<List<dynamic>> _buildCsvData({
    required List<Map<String, dynamic>> previewRows,
    required double totalBudget,
    required double totalSpent,
    required double totalRemaining,
  }) {
    final rows = <List<dynamic>>[
      ['Money Tracking Report'],
      ['Period', _periodLabel],
      [
        'Generated At',
        DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
      ],
      ['Format', _selectedFormat],
      [],
    ];

    if (_includeSummary) {
      rows.addAll([
        ['Summary'],
        ['Total Budget', totalBudget.toStringAsFixed(2)],
        ['Total Spent', totalSpent.toStringAsFixed(2)],
        ['Remaining', totalRemaining.toStringAsFixed(2)],
        [],
      ]);
    }

    if (_includeBudgetVsActual) {
      rows.addAll([
        ['Category', 'Budget', 'Spent', 'Remaining', 'Status'],
        ...previewRows.map((row) {
          final budget = _asDouble(row['budget']);
          final spent = _asDouble(row['spent']);
          final remaining = _asDouble(row['remaining']);
          return [
            row['category'].toString(),
            budget.toStringAsFixed(2),
            spent.toStringAsFixed(2),
            remaining.toStringAsFixed(2),
            row['status'].toString(),
          ];
        }),
      ]);
    }

    return rows;
  }

  String _buildJsonData({
    required List<Map<String, dynamic>> previewRows,
    required double totalBudget,
    required double totalSpent,
    required double totalRemaining,
  }) {
    final payload = <String, dynamic>{
      'title': 'Money Tracking Report',
      'period': _periodLabel,
      'generatedAt': DateTime.now().toIso8601String(),
      'format': _selectedFormat,
      'include': {
        'summary': _includeSummary,
        'budgetVsActual': _includeBudgetVsActual,
        'transactionList': _includeTransactionList,
        'charts': _includeCharts,
      },
      'summary': {
        'totalBudget': totalBudget,
        'totalSpent': totalSpent,
        'totalRemaining': totalRemaining,
      },
      'rows': previewRows
          .map(
            (row) => {
              'category': row['category'],
              'budget': _asDouble(row['budget']),
              'spent': _asDouble(row['spent']),
              'remaining': _asDouble(row['remaining']),
              'status': row['status'],
            },
          )
          .toList(),
    };

    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  Uint8List _buildExcelData({
    required List<Map<String, dynamic>> previewRows,
    required double totalBudget,
    required double totalSpent,
    required double totalRemaining,
  }) {
    final excel = xl.Excel.createExcel();
    final sheet = excel['Report'];
    sheet.appendRow([xl.TextCellValue('Money Tracking Report')]);
    sheet.appendRow([
      xl.TextCellValue('Period'),
      xl.TextCellValue(_periodLabel),
    ]);
    sheet.appendRow([
      xl.TextCellValue('Generated At'),
      xl.TextCellValue(
        DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
      ),
    ]);
    sheet.appendRow([]);

    if (_includeSummary) {
      sheet.appendRow([xl.TextCellValue('Summary')]);
      sheet.appendRow([
        xl.TextCellValue('Total Budget'),
        xl.DoubleCellValue(totalBudget),
      ]);
      sheet.appendRow([
        xl.TextCellValue('Total Spent'),
        xl.DoubleCellValue(totalSpent),
      ]);
      sheet.appendRow([
        xl.TextCellValue('Remaining'),
        xl.DoubleCellValue(totalRemaining),
      ]);
      sheet.appendRow([]);
    }

    if (_includeBudgetVsActual) {
      sheet.appendRow([
        xl.TextCellValue('Category'),
        xl.TextCellValue('Budget'),
        xl.TextCellValue('Spent'),
        xl.TextCellValue('Remaining'),
        xl.TextCellValue('Status'),
      ]);

      for (final row in previewRows) {
        sheet.appendRow([
          xl.TextCellValue(row['category'].toString()),
          xl.DoubleCellValue(_asDouble(row['budget'])),
          xl.DoubleCellValue(_asDouble(row['spent'])),
          xl.DoubleCellValue(_asDouble(row['remaining'])),
          xl.TextCellValue(row['status'].toString()),
        ]);
      }
    }

    final bytes = excel.encode();
    if (bytes == null) {
      throw StateError('Failed to build Excel file.');
    }
    return Uint8List.fromList(bytes);
  }

  Future<Uint8List> _buildPdfData({
    required List<Map<String, dynamic>> previewRows,
    required double totalBudget,
    required double totalSpent,
    required double totalRemaining,
  }) async {
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          final widgets = <pw.Widget>[
            pw.Text(
              'Money Tracking Report',
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            pw.Text('Period: $_periodLabel'),
            pw.Text(
              'Generated: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}',
            ),
            pw.SizedBox(height: 12),
          ];

          if (_includeSummary) {
            widgets.add(
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Summary',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text('Total Budget: ${_money(totalBudget)}'),
                    pw.Text('Total Spent: ${_money(totalSpent)}'),
                    pw.Text('Remaining: ${_money(totalRemaining)}'),
                  ],
                ),
              ),
            );
            widgets.add(pw.SizedBox(height: 12));
          }

          if (_includeBudgetVsActual) {
            widgets.add(
              pw.Table.fromTextArray(
                headers: const [
                  'Category',
                  'Budget',
                  'Spent',
                  'Remaining',
                  'Status',
                ],
                data: previewRows
                    .map(
                      (row) => [
                        row['category'].toString(),
                        _money(_asDouble(row['budget'])),
                        _money(_asDouble(row['spent'])),
                        _money(_asDouble(row['remaining'])),
                        row['status'].toString(),
                      ],
                    )
                    .toList(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.grey300,
                ),
                cellAlignments: {
                  1: pw.Alignment.centerRight,
                  2: pw.Alignment.centerRight,
                  3: pw.Alignment.centerRight,
                  4: pw.Alignment.centerRight,
                },
              ),
            );
          }

          return widgets;
        },
      ),
    );

    return doc.save();
  }

  Future<void> _export({
    required List<Map<String, dynamic>> previewRows,
    required double totalBudget,
    required double totalSpent,
    required double totalRemaining,
  }) async {
    setState(() => _isExporting = true);

    try {
      final dir = await getTemporaryDirectory();
      final baseName = 'money_tracking_report_$_safePeriodLabel';

      late final String fileName;
      late final File outFile;

      switch (_selectedFormat) {
        case 'JSON':
          fileName = '$baseName.json';
          outFile = File('${dir.path}/$fileName');
          await outFile.writeAsString(
            _buildJsonData(
              previewRows: previewRows,
              totalBudget: totalBudget,
              totalSpent: totalSpent,
              totalRemaining: totalRemaining,
            ),
          );
          break;
        case 'CSV':
          fileName = '$baseName.csv';
          outFile = File('${dir.path}/$fileName');
          final csvRows = _buildCsvData(
            previewRows: previewRows,
            totalBudget: totalBudget,
            totalSpent: totalSpent,
            totalRemaining: totalRemaining,
          );
          final csvText = const ListToCsvConverter().convert(csvRows);
          await outFile.writeAsString(csvText);
          break;
        case 'Excel':
          fileName = '$baseName.xlsx';
          outFile = File('${dir.path}/$fileName');
          final bytes = _buildExcelData(
            previewRows: previewRows,
            totalBudget: totalBudget,
            totalSpent: totalSpent,
            totalRemaining: totalRemaining,
          );
          await outFile.writeAsBytes(bytes, flush: true);
          break;
        case 'PDF':
        default:
          fileName = '$baseName.pdf';
          outFile = File('${dir.path}/$fileName');
          final bytes = await _buildPdfData(
            previewRows: previewRows,
            totalBudget: totalBudget,
            totalSpent: totalSpent,
            totalRemaining: totalRemaining,
          );
          await outFile.writeAsBytes(bytes, flush: true);
      }

      await Share.shareXFiles(
        [XFile(outFile.path)],
        text: 'Money Tracking Report ($_periodLabel)',
        subject: 'Money Tracking Report - $_periodLabel',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$_selectedFormat report generated successfully.'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
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
                    'Please sign in to export reports.',
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

                            final categories =
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

                            final previewRows = categories.map((category) {
                              final budget = budgetData[category] ?? 0;
                              final spent = spentData[category] ?? 0;
                              final remaining = budget - spent;
                              final isOver = spent > budget && budget > 0;

                              return <String, dynamic>{
                                'category': category,
                                'budget': budget,
                                'spent': spent,
                                'remaining': remaining,
                                'status': isOver ? 'Over' : 'Under',
                              };
                            }).toList();

                            final totalBudget = budgetData.values.fold<double>(
                              0,
                              (sum, amount) => sum + amount,
                            );
                            final totalSpent = spentData.values.fold<double>(
                              0,
                              (sum, amount) => sum + amount,
                            );
                            final totalRemaining = totalBudget - totalSpent;

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
                                          'Export Report',
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
                                          color: AppColors.walletAccent
                                              .withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: Text(
                                          '${_months[_selectedMonth]} $_selectedYear',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.walletAccent,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Expanded(
                                  child: SingleChildScrollView(
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      8,
                                      16,
                                      24,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _SectionLabel(
                                          icon: Icons.description_rounded,
                                          title: 'Export Format',
                                        ),
                                        GlassCard(
                                          child: Row(
                                            children: _formats.map((fmt) {
                                              final isSelected =
                                                  fmt == _selectedFormat;
                                              return Expanded(
                                                child: GestureDetector(
                                                  onTap: () => setState(
                                                    () => _selectedFormat = fmt,
                                                  ),
                                                  child: Container(
                                                    margin: EdgeInsets.only(
                                                      right:
                                                          fmt != _formats.last
                                                          ? 8
                                                          : 0,
                                                    ),
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          vertical: 10,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: isSelected
                                                          ? AppColors
                                                                .walletAccent
                                                          : Colors.white
                                                                .withValues(
                                                                  alpha: 0.5,
                                                                ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            10,
                                                          ),
                                                    ),
                                                    alignment: Alignment.center,
                                                    child: Column(
                                                      children: [
                                                        Icon(
                                                          _formatIcon(fmt),
                                                          size: 20,
                                                          color: isSelected
                                                              ? Colors.white
                                                              : AppColors
                                                                    .walletAccent,
                                                        ),
                                                        const SizedBox(
                                                          height: 4,
                                                        ),
                                                        Text(
                                                          fmt,
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            color: isSelected
                                                                ? Colors.white
                                                                : Colors.black
                                                                      .withValues(
                                                                        alpha:
                                                                            0.65,
                                                                      ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              );
                                            }).toList(),
                                          ),
                                        ),
                                        const SizedBox(height: 14),
                                        _SectionLabel(
                                          icon: Icons.date_range_rounded,
                                          title: 'Reporting Period',
                                        ),
                                        GlassCard(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              SingleChildScrollView(
                                                scrollDirection:
                                                    Axis.horizontal,
                                                child: Row(
                                                  children: List.generate(_months.length, (
                                                    index,
                                                  ) {
                                                    final isSelected =
                                                        index == _selectedMonth;
                                                    return Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                            right: 8,
                                                          ),
                                                      child: InkWell(
                                                        onTap: () => setState(
                                                          () => _selectedMonth =
                                                              index,
                                                        ),
                                                        child: Container(
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                horizontal: 14,
                                                                vertical: 8,
                                                              ),
                                                          decoration: BoxDecoration(
                                                            color: isSelected
                                                                ? AppColors
                                                                      .walletAccent
                                                                : Colors.white
                                                                      .withValues(
                                                                        alpha:
                                                                            0.5,
                                                                      ),
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  20,
                                                                ),
                                                          ),
                                                          child: Text(
                                                            _months[index],
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700,
                                                              color: isSelected
                                                                  ? Colors.white
                                                                  : Colors
                                                                        .black,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    );
                                                  }),
                                                ),
                                              ),
                                              const SizedBox(height: 10),
                                              Row(
                                                children: [
                                                  Text(
                                                    'Year',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: Colors.black
                                                          .withValues(
                                                            alpha: 0.7,
                                                          ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 12,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.white
                                                          .withValues(
                                                            alpha: 0.5,
                                                          ),
                                                      borderRadius:
                                                          BorderRadius.circular(
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
                                                                        FontWeight
                                                                            .w700,
                                                                  ),
                                                                ),
                                                              ),
                                                            )
                                                            .toList(),
                                                        onChanged: (value) {
                                                          if (value == null) {
                                                            return;
                                                          }
                                                          setState(
                                                            () =>
                                                                _selectedYear =
                                                                    value,
                                                          );
                                                        },
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 14),
                                        _SectionLabel(
                                          icon: Icons.checklist_rounded,
                                          title: 'Include in Report',
                                        ),
                                        GlassCard(
                                          child: Column(
                                            children: [
                                              _CheckTile(
                                                title: 'Summary Overview',
                                                subtitle:
                                                    'Budget, spent, and remaining totals',
                                                value: _includeSummary,
                                                onChanged: (v) => setState(
                                                  () => _includeSummary = v,
                                                ),
                                              ),
                                              const _RowDivider(),
                                              _CheckTile(
                                                title: 'Budget vs Actual',
                                                subtitle:
                                                    'Category-wise comparison',
                                                value: _includeBudgetVsActual,
                                                onChanged: (v) => setState(
                                                  () => _includeBudgetVsActual =
                                                      v,
                                                ),
                                              ),
                                              const _RowDivider(),
                                              _CheckTile(
                                                title: 'Transaction List',
                                                subtitle:
                                                    'All transactions in the period',
                                                value: _includeTransactionList,
                                                onChanged: (v) => setState(
                                                  () =>
                                                      _includeTransactionList =
                                                          v,
                                                ),
                                              ),
                                              const _RowDivider(),
                                              _CheckTile(
                                                title: 'Charts & Graphs',
                                                subtitle:
                                                    'Visual spending breakdown',
                                                value: _includeCharts,
                                                onChanged: (v) => setState(
                                                  () => _includeCharts = v,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 14),
                                        _SectionLabel(
                                          icon: Icons.preview_rounded,
                                          title: 'Report Preview',
                                        ),
                                        GlassCard(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.all(8),
                                                    decoration: BoxDecoration(
                                                      color: AppColors
                                                          .walletAccent
                                                          .withValues(
                                                            alpha: 0.12,
                                                          ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            10,
                                                          ),
                                                    ),
                                                    child: const Icon(
                                                      Icons
                                                          .account_balance_wallet_rounded,
                                                      color: AppColors
                                                          .walletAccent,
                                                      size: 20,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        const Text(
                                                          'Money Tracking Report',
                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.w800,
                                                            fontSize: 14,
                                                          ),
                                                        ),
                                                        Text(
                                                          '${_months[_selectedMonth]} $_selectedYear  â€¢  Generated ${DateFormat('MMM d, yyyy').format(DateTime.now())}',
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            color: Colors.black
                                                                .withValues(
                                                                  alpha: 0.5,
                                                                ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                          vertical: 4,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.blue
                                                          .withValues(
                                                            alpha: 0.12,
                                                          ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            6,
                                                          ),
                                                    ),
                                                    child: Text(
                                                      _selectedFormat,
                                                      style: const TextStyle(
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: Colors.blue,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 14),
                                              const Divider(height: 1),
                                              const SizedBox(height: 12),
                                              Row(
                                                children: [
                                                  _PreviewStat(
                                                    label: 'Total Budget',
                                                    value: _money(totalBudget),
                                                    color: Colors.green,
                                                  ),
                                                  _PreviewStat(
                                                    label: 'Total Spent',
                                                    value: _money(totalSpent),
                                                    color: Colors.orange,
                                                  ),
                                                  _PreviewStat(
                                                    label: 'Remaining',
                                                    value: _money(
                                                      totalRemaining,
                                                    ),
                                                    color: totalRemaining >= 0
                                                        ? Colors.blue
                                                        : Colors.red,
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 12),
                                              if (previewRows.isEmpty)
                                                const Padding(
                                                  padding: EdgeInsets.symmetric(
                                                    vertical: 10,
                                                  ),
                                                  child: Center(
                                                    child: Text(
                                                      'No category or spending data for this period.',
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ),
                                                )
                                              else
                                                Container(
                                                  decoration: BoxDecoration(
                                                    color: Colors.white
                                                        .withValues(
                                                          alpha: 0.45,
                                                        ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          10,
                                                        ),
                                                  ),
                                                  child: Column(
                                                    children: [
                                                      const Padding(
                                                        padding:
                                                            EdgeInsets.symmetric(
                                                              horizontal: 10,
                                                              vertical: 7,
                                                            ),
                                                        child: Row(
                                                          children: [
                                                            Expanded(
                                                              flex: 3,
                                                              child: Text(
                                                                'Category',
                                                                style: TextStyle(
                                                                  fontSize: 11,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w800,
                                                                ),
                                                              ),
                                                            ),
                                                            Expanded(
                                                              flex: 2,
                                                              child: Text(
                                                                'Budget',
                                                                textAlign:
                                                                    TextAlign
                                                                        .right,
                                                                style: TextStyle(
                                                                  fontSize: 11,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w800,
                                                                ),
                                                              ),
                                                            ),
                                                            Expanded(
                                                              flex: 2,
                                                              child: Text(
                                                                'Spent',
                                                                textAlign:
                                                                    TextAlign
                                                                        .right,
                                                                style: TextStyle(
                                                                  fontSize: 11,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w800,
                                                                ),
                                                              ),
                                                            ),
                                                            Expanded(
                                                              flex: 2,
                                                              child: Text(
                                                                'Status',
                                                                textAlign:
                                                                    TextAlign
                                                                        .right,
                                                                style: TextStyle(
                                                                  fontSize: 11,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w800,
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      const Divider(height: 1),
                                                      ...previewRows.map(
                                                        (row) =>
                                                            _TableRow(row: row),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 24),
                                        SizedBox(
                                          width: double.infinity,
                                          child: ElevatedButton.icon(
                                            onPressed: _isExporting
                                                ? null
                                                : () => _export(
                                                    previewRows: previewRows,
                                                    totalBudget: totalBudget,
                                                    totalSpent: totalSpent,
                                                    totalRemaining:
                                                        totalRemaining,
                                                  ),
                                            icon: _isExporting
                                                ? const SizedBox(
                                                    width: 18,
                                                    height: 18,
                                                    child:
                                                        CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                          color: Colors.white,
                                                        ),
                                                  )
                                                : const Icon(
                                                    Icons.download_rounded,
                                                  ),
                                            label: Text(
                                              _isExporting
                                                  ? 'Exporting...'
                                                  : 'Export as $_selectedFormat',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 15,
                                              ),
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  AppColors.walletAccent,
                                              foregroundColor: Colors.white,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 14,
                                                  ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
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

  IconData _formatIcon(String fmt) {
    switch (fmt) {
      case 'PDF':
        return Icons.picture_as_pdf_rounded;
      case 'CSV':
        return Icons.table_chart_rounded;
      case 'Excel':
        return Icons.grid_on_rounded;
      default:
        return Icons.data_object_rounded;
    }
  }
}

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionLabel({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 15, color: AppColors.walletAccent),
          const SizedBox(width: 6),
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.walletAccent,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _CheckTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Checkbox(
          value: value,
          onChanged: (v) => onChanged(v ?? false),
          activeColor: AppColors.walletAccent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.black.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Divider(height: 1, color: Colors.black.withValues(alpha: 0.07)),
    );
  }
}

class _PreviewStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _PreviewStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
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
              color: Colors.black.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }
}

class _TableRow extends StatelessWidget {
  final Map<String, dynamic> row;

  const _TableRow({required this.row});

  @override
  Widget build(BuildContext context) {
    final isOver = (row['status'] as String) == 'Over';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              row['category'] as String,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'â‚¹${(row['budget'] as double).toStringAsFixed(0)}',
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 12),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'â‚¹${(row['spent'] as double).toStringAsFixed(0)}',
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 12),
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: (isOver ? Colors.red : Colors.green).withValues(
                    alpha: 0.15,
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  row['status'] as String,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isOver ? Colors.red : Colors.green,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
