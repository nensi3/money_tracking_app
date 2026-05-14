import 'package:cloud_firestore/cloud_firestore.dart';

class CategoryModel {
  final String id;
  final String name;
  final bool isActive;
  final String type;

  CategoryModel({

    required this.id,
    required this.name,
    required this.isActive,
    required this.type,
  });

  factory CategoryModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return CategoryModel(
      id: doc.id,
      name: data['name'] ?? '',
      isActive: data['isActive'] ?? true,
      type: (data['type'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {'name': name, 'isActive': isActive, 'type': type};
  }
}





























  
