import 'package:flutter/material.dart';

import 'package:money_tracking_app/view/utils/category_ui.dart';

class CategoryProgressBar extends StatelessWidget {
  const CategoryProgressBar({
    super.key,
    required this.category,
    required this.amount,
    required this.maxAmount,
  });

  final String category;
  final double amount;
  final double maxAmount;

  @override
  Widget build(BuildContext context) {
    final progress = maxAmount <= 0
        ? 0.0
        : (amount / maxAmount).clamp(0.0, 1.0);

    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: (CategoryUi.iconBg[category] ?? const Color(0xFFF5F5F5))
                .withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(CategoryUi.iconFor(category), size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    category,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    amount.toStringAsFixed(0),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 7,
                  backgroundColor: Colors.white.withValues(alpha: 0.55),
                  valueColor: const AlwaysStoppedAnimation(Color(0xFF2563EB)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
