import 'package:cloud_firestore/cloud_firestore.dart';

class MoneyTransaction {
  final String id;
  final String userId;
  final double amount;
  final String type; // income / expense
  final String category;
  final String note;
  final DateTime date;
  final String status;
  final DateTime createdAt;

  MoneyTransaction({
    required this.id,
    required this.userId,
    required this.amount,
    required this.type,
    required this.category,
    required this.note,
    required this.date,
    required this.status,
    required this.createdAt,
  });

  factory MoneyTransaction.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final resolvedDate =
        (data['createdAt'] as Timestamp?)?.toDate() ??
        (data['date'] as Timestamp?)?.toDate() ??
        DateTime.now();

    return MoneyTransaction(
      id: doc.id,
      userId: (data['uid'] ?? data['userId'] ?? '').toString(),
      amount: (data['amount'] as num? ?? 0).toDouble(),
      type: (data['type'] ?? 'expense').toString().toLowerCase(),
      category: (data['category'] ?? 'Other').toString(),
      note: (data['note'] ?? data['description'] ?? '').toString(),
      date: resolvedDate,
      status: (data['status'] ?? 'pending').toString().toLowerCase(),
      createdAt: resolvedDate,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': userId,
      'userId': userId,
      'amount': amount,
      'type': type,
      'category': category,
      'note': note,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'date': Timestamp.fromDate(date),
    };
  }
}
