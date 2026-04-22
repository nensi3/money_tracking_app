import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:money_tracking_app/model/transaction_model.dart';
import 'package:money_tracking_app/controller/services/firestore_service.dart';
import 'package:money_tracking_app/controller/services/transaction_service.dart';
import 'package:money_tracking_app/view/utils/app_colors.dart';
import 'package:money_tracking_app/view/widgets/app_gradient_background.dart';
import 'package:money_tracking_app/view/widgets/glass_card.dart';

class AdminApproveTransactionsPage extends StatefulWidget {
  const AdminApproveTransactionsPage({super.key});

  @override
  State<AdminApproveTransactionsPage> createState() =>
      _AdminApproveTransactionsPageState();
}

class _AdminApproveTransactionsPageState
    extends State<AdminApproveTransactionsPage> {
  final TransactionService _transactionService = TransactionService();
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _searchController = TextEditingController();
  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: 'â‚¹',
    decimalDigits: 0,
  );

  String _selectedStatus = 'All';
  String _sortBy = 'Newest';
  String _query = '';
  String? _activeActionTransactionId;
  String? _actionMessage;
  bool _actionMessageIsError = false;

  String _shortId(String id) {
    final clean = id.trim();
    if (clean.length <= 10) return clean;
    return '${clean.substring(0, 10)}...';
  }

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

  Future<void> _approve(TransactionModel transaction) async {
    await _runAction(
      transactionId: transaction.id,
      action: () => _transactionService.approveTransaction(transaction.id),
    );
  }

  Future<void> _reject(TransactionModel transaction) async {
    final reason = await _showRejectionDialog(transaction);
    if (reason == null) return;

    await _runAction(
      transactionId: transaction.id,
      action: () =>
          _transactionService.rejectTransaction(transaction.id, reason),
    );
  }

  Future<void> _runAction({
    required String transactionId,
    required Future<void> Function() action,
  }) async {
    setState(() => _activeActionTransactionId = transactionId);

    try {
      await action().timeout(const Duration(seconds: 12));
      if (!mounted) return;

      setState(() {
        _actionMessage = 'Transaction updated successfully.';
        _actionMessageIsError = false;
      });
    } on TimeoutException {
      if (!mounted) return;

      const message =
          'Request timed out. Check internet/firestore connection and try again.';
      setState(() {
        _actionMessage = message;
        _actionMessageIsError = true;
      });
    } catch (error) {
      if (!mounted) return;

      final message = error.toString().replaceFirst('Bad state: ', '');
      setState(() {
        _actionMessage = message;
        _actionMessageIsError = true;
      });
    } finally {
      if (mounted) {
        setState(() => _activeActionTransactionId = null);
      }
    }
  }

  Future<String?> _showRejectionDialog(TransactionModel transaction) async {
    return showDialog<String>(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) =>
          _RejectReasonDialog(userName: transaction.userName),
    );
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
          transaction.id,
          transaction.userName,
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
              ? const Center(child: Text('Admin session required.'))
              : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: _firestoreService.streamSystemSettings(),
                  builder: (context, settingsSnapshot) {
                    final settings =
                        settingsSnapshot.data?.data() ??
                        const <String, dynamic>{};
                    final maintenanceMode = settings['maintenanceMode'] == true;
                    final autoApprove = settings['autoApprove'] == true;
                    final maxTransactionLimit =
                        (settings['maxTransactionLimit'] ?? 'â‚¹5,000')
                            .toString();
                    final sessionTimeout =
                        (settings['sessionTimeout'] ?? '30 min').toString();
                    final currency = (settings['defaultCurrency'] ?? 'USD')
                        .toString();

                    return StreamBuilder<List<TransactionModel>>(
                      stream: _transactionService.getTransactionsByStatus(
                        'all',
                      ),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Center(
                            child: Text(
                              'Failed to load transactions: ${snapshot.error}',
                            ),
                          );
                        }

                        if (!snapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        final allTransactions = snapshot.data ?? [];
                        final filteredTransactions = _applyFilters(
                          allTransactions,
                        );
                        final pendingCount = allTransactions
                            .where((t) => t.isPending)
                            .length;
                        final approvedCount = allTransactions
                            .where((t) => t.isApproved)
                            .length;
                        final rejectedCount = allTransactions
                            .where((t) => t.isRejected)
                            .length;

                        return SingleChildScrollView(
                          child: Column(
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
                                      onPressed: () => Navigator.pop(context),
                                      icon: const Icon(
                                        Icons.arrow_back_rounded,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Expanded(
                                      child: Text(
                                        'Approve Transactions',
                                        style: TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                    if (pendingCount > 0)
                                      Chip(
                                        label: Text('$pendingCount Pending'),
                                        backgroundColor: Colors.orange
                                            .withValues(alpha: 0.14),
                                        labelStyle: const TextStyle(
                                          color: Colors.orange,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: GlassCard(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.settings_rounded,
                                            color: AppColors.walletAccent,
                                            size: 18,
                                          ),
                                          const SizedBox(width: 8),
                                          const Text(
                                            'Live System Settings',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          const Spacer(),
                                          if (maintenanceMode)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.orange.withValues(
                                                  alpha: 0.15,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(999),
                                              ),
                                              child: const Text(
                                                'Maintenance ON',
                                                style: TextStyle(
                                                  color: Colors.orange,
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Wrap(
                                        spacing: 10,
                                        runSpacing: 10,
                                        children: [
                                          _SettingsChip(
                                            label:
                                                'Auto approve: ${autoApprove ? 'ON' : 'OFF'}',
                                            color: autoApprove
                                                ? Colors.green
                                                : Colors.red,
                                          ),
                                          _SettingsChip(
                                            label:
                                                'Max limit: $maxTransactionLimit',
                                            color: AppColors.walletAccent,
                                          ),
                                          _SettingsChip(
                                            label: 'Timeout: $sessionTimeout',
                                            color: Colors.blue,
                                          ),
                                          _SettingsChip(
                                            label: 'Currency: $currency',
                                            color: Colors.orange,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  children: [
                                    _SummaryCard(
                                      label: 'Pending',
                                      value: pendingCount,
                                      color: Colors.orange,
                                    ),
                                    _SummaryCard(
                                      label: 'Approved',
                                      value: approvedCount,
                                      color: Colors.green,
                                    ),
                                    _SummaryCard(
                                      label: 'Rejected',
                                      value: rejectedCount,
                                      color: Colors.red,
                                    ),
                                    _SummaryCard(
                                      label: 'Total',
                                      value: allTransactions.length,
                                      color: AppColors.walletAccent,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _searchController,
                                        decoration: const InputDecoration(
                                          prefixIcon: Icon(
                                            Icons.search_rounded,
                                          ),
                                          hintText: 'Search transactions',
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    DropdownButton<String>(
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
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                height: 44,
                                child: ListView.separated(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
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
                                      onSelected: (_) => setState(
                                        () => _selectedStatus = status,
                                      ),
                                      selectedColor: AppColors.walletAccent
                                          .withValues(alpha: 0.18),
                                      labelStyle: TextStyle(
                                        color: selected
                                            ? AppColors.walletAccent
                                            : Colors.black87,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    );
                                  },
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(width: 8),
                                  itemCount: 4,
                                ),
                              ),
                              const SizedBox(height: 12),
                              if (maintenanceMode)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withValues(
                                        alpha: 0.12,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Text(
                                      'Maintenance mode is ON. Users are blocked, but admin approvals are still available.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                ),
                              if (maintenanceMode) const SizedBox(height: 12),
                              if (_actionMessage != null)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: _actionMessageIsError
                                          ? Colors.red.withValues(alpha: 0.12)
                                          : Colors.green.withValues(
                                              alpha: 0.12,
                                            ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      _actionMessage!,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: _actionMessageIsError
                                            ? Colors.red.shade800
                                            : Colors.green.shade800,
                                      ),
                                    ),
                                  ),
                                ),
                              if (_actionMessage != null)
                                const SizedBox(height: 12),
                              filteredTransactions.isEmpty
                                  ? const Padding(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 24,
                                      ),
                                      child: Center(
                                        child: Text('No transactions found.'),
                                      ),
                                    )
                                  : ListView.separated(
                                      padding: const EdgeInsets.fromLTRB(
                                        16,
                                        0,
                                        16,
                                        20,
                                      ),
                                      shrinkWrap: true,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      itemCount: filteredTransactions.length,
                                      separatorBuilder: (_, __) =>
                                          const SizedBox(height: 12),
                                      itemBuilder: (context, index) {
                                        final transaction =
                                            filteredTransactions[index];
                                        final isActionInProgress =
                                            _activeActionTransactionId ==
                                            transaction.id;

                                        return GlassCard(
                                          padding: const EdgeInsets.all(16),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  _TransactionTypeIcon(
                                                    type: transaction.type,
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          transaction.userName,
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 16,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w800,
                                                              ),
                                                        ),
                                                        const SizedBox(
                                                          height: 2,
                                                        ),
                                                        Text(
                                                          transaction.userEmail
                                                                      ?.trim()
                                                                      .isNotEmpty ==
                                                                  true
                                                              ? '${transaction.userEmail} â€¢ UID: ${_shortId(transaction.userId)}'
                                                              : 'UID: ${_shortId(transaction.userId)}',
                                                          style: TextStyle(
                                                            color: Colors.black
                                                                .withValues(
                                                                  alpha: 0.6,
                                                                ),
                                                            fontSize: 11,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          height: 2,
                                                        ),
                                                        Text(
                                                          '${transaction.category} â€¢ ${DateFormat('dd MMM yyyy, hh:mm a').format(transaction.date)}',
                                                          style: TextStyle(
                                                            color: Colors.black
                                                                .withValues(
                                                                  alpha: 0.55,
                                                                ),
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
                                                  color: Colors.black
                                                      .withValues(alpha: 0.72),
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
                                                      fontWeight:
                                                          FontWeight.w900,
                                                      color:
                                                          transaction.type ==
                                                              'income'
                                                          ? Colors.green
                                                          : Colors.red,
                                                    ),
                                                  ),
                                                  const Spacer(),
                                                  if (transaction
                                                      .isPending) ...[
                                                    OutlinedButton(
                                                      onPressed:
                                                          isActionInProgress
                                                          ? null
                                                          : () => _reject(
                                                              transaction,
                                                            ),
                                                      style:
                                                          OutlinedButton.styleFrom(
                                                            foregroundColor:
                                                                Colors.red,
                                                          ),
                                                      child: isActionInProgress
                                                          ? const SizedBox(
                                                              width: 16,
                                                              height: 16,
                                                              child:
                                                                  CircularProgressIndicator(
                                                                    strokeWidth:
                                                                        2,
                                                                  ),
                                                            )
                                                          : const Text(
                                                              'Reject',
                                                            ),
                                                    ),
                                                    const SizedBox(width: 10),
                                                    FilledButton(
                                                      onPressed:
                                                          isActionInProgress
                                                          ? null
                                                          : () => _approve(
                                                              transaction,
                                                            ),
                                                      style:
                                                          FilledButton.styleFrom(
                                                            backgroundColor:
                                                                Colors.green,
                                                          ),
                                                      child: isActionInProgress
                                                          ? const SizedBox(
                                                              width: 16,
                                                              height: 16,
                                                              child:
                                                                  CircularProgressIndicator(
                                                                    strokeWidth:
                                                                        2,
                                                                    color: Colors
                                                                        .white,
                                                                  ),
                                                            )
                                                          : const Text(
                                                              'Approve',
                                                            ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                              if ((transaction
                                                          .rejectionReason ??
                                                      '')
                                                  .isNotEmpty) ...[
                                                const SizedBox(height: 8),
                                                Text(
                                                  'Reason: ${transaction.rejectionReason}',
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

class _SettingsChip extends StatelessWidget {
  final String label;
  final Color color;

  const _SettingsChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color.withValues(alpha: 0.85),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$value',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TransactionTypeIcon extends StatelessWidget {
  final String type;

  const _TransactionTypeIcon({required this.type});

  @override
  Widget build(BuildContext context) {
    final isIncome = type.toLowerCase() == 'income';
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: (isIncome ? Colors.green : Colors.red).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(
        isIncome ? Icons.trending_up_rounded : Icons.trending_down_rounded,
        color: isIncome ? Colors.green : Colors.red,
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

class _RejectReasonDialog extends StatefulWidget {
  final String userName;

  const _RejectReasonDialog({required this.userName});

  @override
  State<_RejectReasonDialog> createState() => _RejectReasonDialogState();
}

class _RejectReasonDialogState extends State<_RejectReasonDialog> {
  final TextEditingController _controller = TextEditingController();
  String? _validationError;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reject Transaction'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Enter a reason for rejecting ${widget.userName}\'s transaction.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Rejection reason',
                border: const OutlineInputBorder(),
                errorText: _validationError,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            FocusManager.instance.primaryFocus?.unfocus();
            final reason = _controller.text.trim();
            if (reason.isEmpty) {
              setState(() {
                _validationError = 'Rejection reason is required.';
              });
              return;
            }
            Navigator.pop(context, reason);
          },
          child: const Text('Reject'),
        ),
      ],
    );
  }
}
