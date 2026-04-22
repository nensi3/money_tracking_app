import 'package:flutter/material.dart';

class CategoryUi {
  static const Map<String, Color> iconBg = {
    'Food': Color(0xFFFFD6E8),
    'Transport': Color(0xFFD6F3FF),
    'Shopping': Color(0xFFFFF1CC),
    'Bills': Color(0xFFDFF7E4),
    'Rent': Color(0xFFE9DDFF),
    'Travel': Color(0xFFD6F3FF),
    'Entertainment': Color(0xFFE9DDFF),
    'Salary': Color(0xFFD6F3FF),
    'Business': Color(0xFFDFF7E4),
    'Freelance': Color(0xFFFFF1CC),
    'Investment': Color(0xFFE9DDFF),
    'Gift': Color(0xFFFFD6E8),
    'Other': Color(0xFFF5F5F5),
  };

  static IconData iconFor(String category) {
    switch (category) {
      case 'Food':
        return Icons.restaurant_rounded;
      case 'Transport':
        return Icons.directions_car_rounded;
      case 'Shopping':
        return Icons.shopping_bag_rounded;
      case 'Bills':
        return Icons.receipt_long_rounded;
      case 'Rent':
        return Icons.home_rounded;
      case 'Travel':
        return Icons.flight_takeoff_rounded;
      case 'Entertainment':
        return Icons.movie_rounded;
      case 'Salary':
        return Icons.payments_rounded;
      case 'Business':
        return Icons.store_rounded;
      case 'Freelance':
        return Icons.laptop_mac_rounded;
      case 'Investment':
        return Icons.trending_up_rounded;
      case 'Gift':
        return Icons.card_giftcard_rounded;
      default:
        return Icons.category_rounded;
    }
  }
}
