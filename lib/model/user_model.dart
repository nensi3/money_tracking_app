import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String name;
  final String email;
  final String role; // 'User', 'Moderator', 'Admin'
  final bool active;
  final DateTime joinedDate;
  final int transactionCount;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    required this.active,
    required this.joinedDate,
    required this.transactionCount,
  });

  factory UserModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return UserModel(
      uid: doc.id,
      name: (data['name'] ?? 'Unknown').toString(),
      email: (data['email'] ?? '').toString(),
      role: (data['role'] ?? 'User').toString(),
      active: (data['active'] ?? true) as bool,
      joinedDate:
          (data['joinedDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      transactionCount: (data['transactionCount'] ?? 0) as int,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'role': role,
      'active': active,
      'joinedDate': Timestamp.fromDate(joinedDate),
      'transactionCount': transactionCount,
    };
  }

  UserModel copyWith({
    String? uid,
    String? name,
    String? email,
    String? role,
    bool? active,
    DateTime? joinedDate,
    int? transactionCount,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      active: active ?? this.active,
      joinedDate: joinedDate ?? this.joinedDate,
      transactionCount: transactionCount ?? this.transactionCount,
    );
  }
}
