import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import 'package:money_tracking_app/model/transaction_model.dart';
import 'package:money_tracking_app/controller/services/budget_service.dart';
import 'package:money_tracking_app/controller/services/transaction_service.dart';
import 'package:money_tracking_app/view/utils/app_colors.dart';
import 'package:money_tracking_app/view/widgets/app_gradient_background.dart';
import 'package:money_tracking_app/view/widgets/glass_card.dart';

class EmailSummaryPage extends StatefulWidget {
  const EmailSummaryPage({super.key});

  @override
  State<EmailSummaryPage> createState() => _EmailSummaryPageState();
}

class _EmailSummaryPageState extends State<EmailSummaryPage> {
  final _recipientController = TextEditingController();
  final _subjectController = TextEditingController();
  final _noteController = TextEditingController(
    text: 'Please find your budget summary below.',
  );

  final TransactionService _transactionService = TransactionService();
  final BudgetService _budgetService = BudgetService();
  final NumberFormat _money = NumberFormat.currency(
    locale: 'en_IN',
    symbol: 'Rs ',
    decimalDigits: 0,
  );

  String _selectedRange = 'This Month';
  bool _attachPDF = true;
  bool _attachCSV = false;
  bool _includeSummaryTable = true;
  bool _includeSpendingTips = true;
  bool _isSending = false;

  Future<Map<String, double>>? _budgetFuture;
  String? _budgetFutureKey;
  _PreparedSummary? _latestPrepared;

  static const List<String> _ranges = [
    'This Month',
    'Last Month',
    'Last 3 Months',
    'Last 6 Months',
  ];

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    _recipientController.text = user?.email ?? '';
    _subjectController.text =
        'Budget Summary - ${DateFormat('MMMM yyyy').format(DateTime.now())}';
  }

  @override
  void dispose() {
    _recipientController.dispose();
    _subjectController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  String _monthKey(DateTime month) => _budgetService.monthKey(month);

  List<DateTime> _monthsForRange() {
    final now = DateTime.now();
    switch (_selectedRange) {
      case 'Last Month':
        return [DateTime(now.year, now.month - 1, 1)];
      case 'Last 3 Months':
        return List.generate(
          3,
          (i) => DateTime(now.year, now.month - i, 1),
        ).reversed.toList();
      case 'Last 6 Months':
        return List.generate(
          6,
          (i) => DateTime(now.year, now.month - i, 1),
        ).reversed.toList();
      case 'This Month':
      default:
        return [DateTime(now.year, now.month, 1)];
    }
  }

  bool _sameMonth(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month;
  }

  Future<Map<String, double>> _loadBudgetsForRange(
    String uid,
    List<DateTime> months,
  ) async {
    final out = <String, double>{};

    for (final month in months) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('budgets')
          .doc(_monthKey(month))
          .get();

      final categories =
          (doc.data()?['categories'] as Map<String, dynamic>?) ??
          <String, dynamic>{};

      for (final entry in categories.entries) {
        final category = entry.key.trim();
        final value = (entry.value as num?)?.toDouble() ?? 0;
        out[category] = (out[category] ?? 0) + value;
      }
    }

    return out;
  }

  Map<String, double> _loadSpentForRange(
    List<TransactionModel> transactions,
    List<DateTime> months,
  ) {
    final out = <String, double>{};

    for (final tx in transactions) {
      if (tx.status.toLowerCase() != 'approved') continue;
      if (tx.type.toLowerCase() != 'expense') continue;

      final inRange = months.any((m) => _sameMonth(tx.date, m));
      if (!inRange) continue;

      final category = tx.category.trim().isEmpty
          ? 'Other'
          : tx.category.trim();
      out[category] = (out[category] ?? 0) + tx.amount;
    }

    return out;
  }

  Future<Map<String, double>> _ensureBudgetFuture(String uid) {
    final key = '$uid|$_selectedRange';
    if (_budgetFuture == null || _budgetFutureKey != key) {
      _budgetFutureKey = key;
      _budgetFuture = _loadBudgetsForRange(uid, _monthsForRange());
    }
    return _budgetFuture!;
  }

  List<String> _buildTips(List<_SummaryRow> rows) {
    if (rows.isEmpty) {
      return const ['No expense data found for the selected range.'];
    }

    final tips = <String>[];

    final overBudget = rows.where((r) => r.budget > 0 && r.spent > r.budget);
    for (final row in overBudget.take(2)) {
      tips.add(
        '${row.category}: over budget by ${_money.format(row.spent - row.budget)}.',
      );
    }

    final mostSpent = rows.toList()..sort((a, b) => b.spent.compareTo(a.spent));
    final top = mostSpent.first;
    tips.add('${top.category} is your top spending category this period.');

    final underBudget = rows.where((r) => r.budget > 0 && r.spent <= r.budget);
    final winner = underBudget.isEmpty
        ? null
        : (underBudget.toList()..sort((a, b) {
                final aSaved = a.budget - a.spent;
                final bSaved = b.budget - b.spent;
                return bSaved.compareTo(aSaved);
              }))
              .first;

    if (winner != null) {
      tips.add(
        'Good control in ${winner.category}: saved ${_money.format(winner.budget - winner.spent)} vs budget.',
      );
    }

    return tips;
  }

  bool _isValidEmail(String text) {
    final email = text.trim();
    if (email.isEmpty) return false;
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
  }

  Future<List<XFile>> _buildAttachments(_PreparedSummary summary) async {
    final dir = await getTemporaryDirectory();
    final safeRange = _selectedRange.toLowerCase().replaceAll(' ', '_');
    final files = <XFile>[];

    if (_attachCSV) {
      final csvRows = <List<dynamic>>[
        ['Category', 'Budget', 'Spent', 'Remaining', 'Status'],
      ];

      for (final row in summary.rows) {
        final remaining = row.budget - row.spent;
        csvRows.add([
          row.category,
          row.budget.toStringAsFixed(2),
          row.spent.toStringAsFixed(2),
          remaining.toStringAsFixed(2),
          row.budget > 0 && row.spent > row.budget ? 'Over budget' : 'OK',
        ]);
      }

      csvRows.add([
        'TOTAL',
        summary.totalBudget.toStringAsFixed(2),
        summary.totalSpent.toStringAsFixed(2),
        (summary.totalBudget - summary.totalSpent).toStringAsFixed(2),
        '',
      ]);

      final csvString = const ListToCsvConverter().convert(csvRows);
      final csvFile = File('${dir.path}/budget_summary_$safeRange.csv');
      await csvFile.writeAsString(csvString, flush: true);
      files.add(XFile(csvFile.path));
    }

    if (_attachPDF) {
      final pdf = pw.Document();
      pdf.addPage(
        pw.MultiPage(
          build: (context) => [
            pw.Header(
              level: 0,
              child: pw.Text('Budget Summary ($_selectedRange)'),
            ),
            pw.Paragraph(text: _noteController.text.trim()),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headers: ['Category', 'Budget', 'Spent', 'Remaining'],
              data: summary.rows
                  .map(
                    (r) => [
                      r.category,
                      r.budget.toStringAsFixed(0),
                      r.spent.toStringAsFixed(0),
                      (r.budget - r.spent).toStringAsFixed(0),
                    ],
                  )
                  .toList(),
            ),
            pw.SizedBox(height: 10),
            pw.Text(
              'Total: ${summary.totalSpent.toStringAsFixed(0)} / ${summary.totalBudget.toStringAsFixed(0)}',
            ),
            if (_includeSpendingTips) ...[
              pw.SizedBox(height: 10),
              pw.Text('Spending Tips', style: pw.TextStyle(fontSize: 14)),
              ...summary.tips.map((t) => pw.Bullet(text: t)),
            ],
          ],
        ),
      );

      final pdfFile = File('${dir.path}/budget_summary_$safeRange.pdf');
      await pdfFile.writeAsBytes(await pdf.save(), flush: true);
      files.add(XFile(pdfFile.path));
    }

    return files;
  }

  Future<void> _send() async {
    final prepared = _latestPrepared;
    if (prepared == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Summary data is still loading. Please try again.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final recipient = _recipientController.text.trim();
    if (!_isValidEmail(recipient)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid recipient email.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSending = true);

    try {
      final subject = _subjectController.text.trim().isEmpty
          ? 'Budget Summary ($_selectedRange)'
          : _subjectController.text.trim();

      final bodyLines = <String>[
        _noteController.text.trim(),
        '',
        'Period: $_selectedRange',
        'Total Spent: ${_money.format(prepared.totalSpent)}',
        'Total Budget: ${_money.format(prepared.totalBudget)}',
        'Remaining: ${_money.format(prepared.totalBudget - prepared.totalSpent)}',
      ];

      if (_includeSummaryTable && prepared.rows.isNotEmpty) {
        bodyLines.add('');
        bodyLines.add('Category Summary:');
        for (final row in prepared.rows) {
          bodyLines.add(
            '- ${row.category}: ${_money.format(row.spent)} / ${_money.format(row.budget)}',
          );
        }
      }

      if (_includeSpendingTips && prepared.tips.isNotEmpty) {
        bodyLines.add('');
        bodyLines.add('Spending Tips:');
        for (final tip in prepared.tips) {
          bodyLines.add('- $tip');
        }
      }

      final body = bodyLines.join('\n');
      final files = await _buildAttachments(prepared);

      if (files.isEmpty) {
        await Share.share('To: $recipient\n\n$body', subject: subject);
      } else {
        await Share.shareXFiles(files, subject: subject, text: body);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Summary prepared for $recipient.'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Email summary failed: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
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
                    'Please sign in to use email summary.',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                )
              : StreamBuilder<List<TransactionModel>>(
                  stream: _transactionService.getUserTransactions(
                    currentUser.uid,
                  ),
                  builder: (context, txSnapshot) {
                    if (txSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final allTransactions =
                        txSnapshot.data ?? const <TransactionModel>[];

                    return FutureBuilder<Map<String, double>>(
                      future: _ensureBudgetFuture(currentUser.uid),
                      builder: (context, budgetSnapshot) {
                        if (budgetSnapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        final months = _monthsForRange();
                        final spentMap = _loadSpentForRange(
                          allTransactions,
                          months,
                        );
                        final budgetMap =
                            budgetSnapshot.data ?? const <String, double>{};

                        final categories = <String>{
                          ...budgetMap.keys,
                          ...spentMap.keys,
                        }.toList()..sort();

                        final rows = categories
                            .map(
                              (category) => _SummaryRow(
                                category: category,
                                budget: budgetMap[category] ?? 0,
                                spent: spentMap[category] ?? 0,
                              ),
                            )
                            .toList();

                        final totalBudget = rows.fold<double>(
                          0,
                          (total, row) => total + row.budget,
                        );
                        final totalSpent = rows.fold<double>(
                          0,
                          (total, row) => total + row.spent,
                        );
                        final tips = _buildTips(rows);

                        _latestPrepared = _PreparedSummary(
                          rows: rows,
                          tips: tips,
                          totalBudget: totalBudget,
                          totalSpent: totalSpent,
                        );

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
                                      'Email Summary',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.send_rounded,
                                      color: AppColors.walletAccent,
                                    ),
                                    onPressed: _isSending ? null : _send,
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const _SectionLabel(
                                      icon: Icons.edit_rounded,
                                      title: 'Compose',
                                    ),
                                    GlassCard(
                                      child: Column(
                                        children: [
                                          _EmailField(
                                            label: 'To',
                                            icon: Icons.person_rounded,
                                            controller: _recipientController,
                                            keyboardType:
                                                TextInputType.emailAddress,
                                          ),
                                          const _RowDivider(),
                                          _EmailField(
                                            label: 'Subject',
                                            icon: Icons.subject_rounded,
                                            controller: _subjectController,
                                          ),
                                          const _RowDivider(),
                                          TextField(
                                            controller: _noteController,
                                            maxLines: 3,
                                            decoration: InputDecoration(
                                              hintText:
                                                  'Add a personal note...',
                                              filled: true,
                                              fillColor: Colors.white
                                                  .withValues(alpha: 0.45),
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                borderSide: BorderSide.none,
                                              ),
                                              contentPadding:
                                                  const EdgeInsets.all(12),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    const _SectionLabel(
                                      icon: Icons.date_range_rounded,
                                      title: 'Reporting Period',
                                    ),
                                    GlassCard(
                                      child: Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: _ranges.map((r) {
                                          final isSelected =
                                              r == _selectedRange;
                                          return GestureDetector(
                                            onTap: () => setState(() {
                                              _selectedRange = r;
                                              _budgetFuture = null;
                                            }),
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 14,
                                                    vertical: 8,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: isSelected
                                                    ? AppColors.walletAccent
                                                    : Colors.white.withValues(
                                                        alpha: 0.5,
                                                      ),
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                              child: Text(
                                                r,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                  color: isSelected
                                                      ? Colors.white
                                                      : Colors.black.withValues(
                                                          alpha: 0.65,
                                                        ),
                                                ),
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    const _SectionLabel(
                                      icon: Icons.attach_file_rounded,
                                      title: 'Attachments & Content',
                                    ),
                                    GlassCard(
                                      child: Column(
                                        children: [
                                          _ToggleRow(
                                            icon: Icons.picture_as_pdf_rounded,
                                            iconColor: Colors.red,
                                            title: 'Attach PDF Report',
                                            value: _attachPDF,
                                            onChanged: (v) =>
                                                setState(() => _attachPDF = v),
                                          ),
                                          const _RowDivider(),
                                          _ToggleRow(
                                            icon: Icons.table_chart_rounded,
                                            iconColor: Colors.green,
                                            title: 'Attach CSV Data',
                                            value: _attachCSV,
                                            onChanged: (v) =>
                                                setState(() => _attachCSV = v),
                                          ),
                                          const _RowDivider(),
                                          _ToggleRow(
                                            icon: Icons.table_rows_rounded,
                                            iconColor: Colors.blue,
                                            title: 'Include Summary Table',
                                            value: _includeSummaryTable,
                                            onChanged: (v) => setState(
                                              () => _includeSummaryTable = v,
                                            ),
                                          ),
                                          const _RowDivider(),
                                          _ToggleRow(
                                            icon:
                                                Icons.tips_and_updates_rounded,
                                            iconColor: Colors.orange,
                                            title: 'Include Spending Tips',
                                            value: _includeSpendingTips,
                                            onChanged: (v) => setState(
                                              () => _includeSpendingTips = v,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    const _SectionLabel(
                                      icon: Icons.preview_rounded,
                                      title: 'Email Preview',
                                    ),
                                    GlassCard(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withValues(
                                                alpha: 0.55,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                _PreviewField(
                                                  label: 'To',
                                                  value:
                                                      _recipientController
                                                          .text
                                                          .isEmpty
                                                      ? 'â€”'
                                                      : _recipientController
                                                            .text,
                                                ),
                                                const SizedBox(height: 4),
                                                _PreviewField(
                                                  label: 'Subject',
                                                  value:
                                                      _subjectController
                                                          .text
                                                          .isEmpty
                                                      ? 'â€”'
                                                      : _subjectController.text,
                                                ),
                                                const SizedBox(height: 4),
                                                _PreviewField(
                                                  label: 'Period',
                                                  value: _selectedRange,
                                                ),
                                                if (_attachPDF ||
                                                    _attachCSV) ...[
                                                  const SizedBox(height: 4),
                                                  Row(
                                                    children: [
                                                      Text(
                                                        'Attachments: ',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          color: Colors.black
                                                              .withValues(
                                                                alpha: 0.5,
                                                              ),
                                                        ),
                                                      ),
                                                      if (_attachPDF)
                                                        const _AttachBadge(
                                                          label: 'summary.pdf',
                                                          color: Colors.red,
                                                        ),
                                                      if (_attachCSV) ...[
                                                        const SizedBox(
                                                          width: 4,
                                                        ),
                                                        const _AttachBadge(
                                                          label: 'summary.csv',
                                                          color: Colors.green,
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          if (_noteController.text
                                              .trim()
                                              .isNotEmpty) ...[
                                            Text(
                                              _noteController.text.trim(),
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontStyle: FontStyle.italic,
                                              ),
                                            ),
                                            const SizedBox(height: 12),
                                          ],
                                          if (_includeSummaryTable) ...[
                                            const Text(
                                              'Budget Summary',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 13,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            if (rows.isEmpty)
                                              const Text(
                                                'No summary rows found.',
                                              ),
                                            ...rows.map((row) {
                                              final isOver =
                                                  row.budget > 0 &&
                                                  row.spent > row.budget;
                                              return Padding(
                                                padding: const EdgeInsets.only(
                                                  bottom: 6,
                                                ),
                                                child: Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        row.category,
                                                        style: const TextStyle(
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                      ),
                                                    ),
                                                    Text(
                                                      '${_money.format(row.spent)} / ${_money.format(row.budget)}',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: isOver
                                                            ? Colors.red
                                                            : Colors.green,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            }),
                                            const Divider(),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                const Text(
                                                  'Total',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w800,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                                Text(
                                                  '${_money.format(totalSpent)} / ${_money.format(totalBudget)}',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w800,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                          if (_includeSpendingTips) ...[
                                            const SizedBox(height: 12),
                                            const Text(
                                              'Spending Tips',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 13,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            ...tips.map(
                                              (tip) => Padding(
                                                padding: const EdgeInsets.only(
                                                  bottom: 5,
                                                ),
                                                child: Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    const Icon(
                                                      Icons.lightbulb_rounded,
                                                      size: 14,
                                                      color: Colors.amber,
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Expanded(
                                                      child: Text(
                                                        tip,
                                                        style: const TextStyle(
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        onPressed: _isSending ? null : _send,
                                        icon: _isSending
                                            ? const SizedBox(
                                                width: 18,
                                                height: 18,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: Colors.white,
                                                    ),
                                              )
                                            : const Icon(Icons.send_rounded),
                                        label: Text(
                                          _isSending
                                              ? 'Preparing...'
                                              : 'Send Email Summary',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 15,
                                          ),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              AppColors.walletAccent,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 14,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
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
                ),
        ),
      ),
    );
  }
}

class _PreparedSummary {
  final List<_SummaryRow> rows;
  final List<String> tips;
  final double totalBudget;
  final double totalSpent;

  const _PreparedSummary({
    required this.rows,
    required this.tips,
    required this.totalBudget,
    required this.totalSpent,
  });
}

class _SummaryRow {
  final String category;
  final double budget;
  final double spent;

  const _SummaryRow({
    required this.category,
    required this.budget,
    required this.spent,
  });
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

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Divider(height: 1, color: Colors.black.withValues(alpha: 0.07)),
    );
  }
}

class _EmailField extends StatelessWidget {
  final String label;
  final IconData icon;
  final TextEditingController controller;
  final TextInputType? keyboardType;

  const _EmailField({
    required this.label,
    required this.icon,
    required this.controller,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.walletAccent),
        const SizedBox(width: 8),
        Text(
          '$label:',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.black.withValues(alpha: 0.55),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            style: const TextStyle(fontSize: 13),
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
      ],
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: iconColor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: AppColors.walletAccent,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ],
    );
  }
}

class _PreviewField extends StatelessWidget {
  final String label;
  final String value;
  const _PreviewField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 60,
          child: Text(
            '$label:',
            style: TextStyle(
              fontSize: 11,
              color: Colors.black.withValues(alpha: 0.5),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _AttachBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _AttachBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
