import 'package:cloud_firestore/cloud_firestore.dart';

class TransactionModel {
  final String id;
  final String userId;
  final String userName;
  final String? userEmail;
  final double amount;
  final String category;
  final String description;
  final DateTime date;
  final String status;
  final String type;
  final String? rejectionReason;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TransactionModel({
    required this.id,
    required this.userId,
    required this.userName,
    this.userEmail,
    required this.amount,
    required this.category,
    required this.description,
    required this.date,
    required this.status,
    required this.type,
    required this.createdAt,
    required this.updatedAt,
    this.rejectionReason,
  });

  bool get isPending => status.toLowerCase() == 'pending';
  bool get isApproved => status.toLowerCase() == 'approved';
  bool get isRejected => status.toLowerCase() == 'rejected';

  TransactionModel copyWith({
    String? id,
    String? userId,
    String? userName,
    String? userEmail,
    double? amount,
    String? category,
    String? description,
    DateTime? date,
    String? status,
    String? type,
    String? rejectionReason,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userEmail: userEmail ?? this.userEmail,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      description: description ?? this.description,
      date: date ?? this.date,
      status: status ?? this.status,
      type: type ?? this.type,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory TransactionModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    return TransactionModel.fromMap(doc.data() ?? {}, id: doc.id);
  }

  factory TransactionModel.fromMap(Map<String, dynamic> map, {String? id}) {
    final date = _asDateTime(map['date']) ?? DateTime.now();

    return TransactionModel(
      id: id ?? (map['id'] ?? '').toString(),
      userId: (map['userId'] ?? '').toString(),
      userName: (map['userName'] ?? '').toString(),
      userEmail: _nullableString(map['userEmail']),
      amount: _asDouble(map['amount']),
      category: (map['category'] ?? 'Other').toString(),
      description: (map['description'] ?? map['note'] ?? '').toString(),
      date: date,
      status: _normalizeStatus(map['status']),
      type: (map['type'] ?? 'expense').toString().toLowerCase(),
      rejectionReason: _nullableString(map['rejectionReason']),
      createdAt: _asDateTime(map['createdAt']) ?? date,
      updatedAt: _asDateTime(map['updatedAt']) ?? date,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'amount': amount,
      'category': category,
      'description': description,
      'date': Timestamp.fromDate(date),
      'status': status,
      'type': type,
      'rejectionReason': rejectionReason,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  static DateTime? _asDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static double _asDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String _normalizeStatus(dynamic value) {
    final normalized = (value ?? 'Pending').toString().trim().toLowerCase();
    switch (normalized) {
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      default:
        return 'Pending';
    }
  }

  static String? _nullableString(dynamic value) {
    final text = (value ?? '').toString().trim();
    return text.isEmpty ? null : text;
  }
}
