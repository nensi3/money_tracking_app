import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:money_tracking_app/model/money_transaction.dart';
import 'package:money_tracking_app/view/utils/category_ui.dart';
import 'glass_card.dart';

class TransactionCard extends StatelessWidget {
  const TransactionCard({
    super.key,
    required this.transaction,
    required this.onDelete,
  });

  final MoneyTransaction transaction;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.type == 'income';
    final iconBg =
        CategoryUi.iconBg[transaction.category] ?? const Color(0xFFF5F5F5);

    return GlassCard(
      opacity: 0.85,
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(CategoryUi.iconFor(transaction.category), size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.category,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  transaction.note.isEmpty ? 'No note' : transaction.note,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.black.withValues(alpha: 0.65),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat(
                    'dd MMM yyyy, hh:mm a',
                  ).format(transaction.createdAt),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.black.withValues(alpha: 0.5),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isIncome ? '+ ' : '- '}${transaction.amount.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: isIncome ? Colors.green : Colors.red,
                ),
              ),
              Text(
                transaction.status.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: transaction.status == 'approved'
                      ? Colors.green
                      : transaction.status == 'rejected'
                      ? Colors.red
                      : Colors.orange,
                ),
              ),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
