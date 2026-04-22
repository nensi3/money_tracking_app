import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:money_tracking_app/model/category_model.dart';

class CategoryService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const List<Map<String, String>> _defaultCategories = [
    {'name': 'Food', 'type': 'expense'},
    {'name': 'Transport', 'type': 'expense'},
    {'name': 'Shopping', 'type': 'expense'},
    {'name': 'Bills', 'type': 'expense'},
    {'name': 'Health', 'type': 'expense'},
    {'name': 'Salary', 'type': 'income'},
    {'name': 'Freelance', 'type': 'income'},
    {'name': 'Other', 'type': 'both'},
  ];

  CollectionReference<Map<String, dynamic>> _userCategories(String uid) {
    return _db.collection('users').doc(uid).collection('categories');
  }

  Future<void> ensureDefaultCategories({required String uid}) async {
    final normalizedUid = uid.trim();
    if (normalizedUid.isEmpty) return;

    final existing = await _userCategories(normalizedUid).limit(1).get();
    if (existing.docs.isNotEmpty) {
      return;
    }

    final batch = _db.batch();
    for (final entry in _defaultCategories) {
      final docRef = _userCategories(normalizedUid).doc();
      batch.set(docRef, {
        'uid': normalizedUid,
        'name': entry['name'],
        'isActive': true,
        'type': entry['type'],
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  Stream<List<CategoryModel>> getActiveCategories({String? type}) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null || uid.trim().isEmpty) {
      return Stream<List<CategoryModel>>.value(const <CategoryModel>[]);
    }

    return _userCategories(
      uid,
    ).where('isActive', isEqualTo: true).snapshots().map((snapshot) {
      final categories = snapshot.docs
          .map((doc) => CategoryModel.fromDoc(doc))
          .toList();

      if (type == null || type.isEmpty) {
        return categories;
      }

      return categories
          .where((category) => category.type == type || category.type == 'both')
          .toList();
    });
  }

  Stream<List<CategoryModel>> getCategories() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.trim().isEmpty) {
      return Stream<List<CategoryModel>>.value(const <CategoryModel>[]);
    }

    return _userCategories(uid).snapshots().map(
      (snapshot) =>
          snapshot.docs.map((doc) => CategoryModel.fromDoc(doc)).toList(),
    );
  }

  Future<void> addCategory(String name, {String type = 'expense'}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.trim().isEmpty) {
      throw StateError('You must be signed in to add categories.');
    }

    await _userCategories(uid).add({
      'uid': uid,
      'name': name,
      'isActive': true,
      'type': type,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateCategory(
    String id, {
    required String name,
    required String type,
    bool? isActive,
  }) async {
    if (id.trim().isEmpty) {
      throw StateError('Category id cannot be empty.');
    }

    final updateData = <String, dynamic>{'name': name, 'type': type};

    if (isActive != null) {
      updateData['isActive'] = isActive;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.trim().isEmpty) {
      throw StateError('You must be signed in to update categories.');
    }

    await _userCategories(uid).doc(id).update(updateData);
  }

  Future<void> deleteCategory(String id) async {
    if (id.trim().isEmpty) {
      throw StateError('Category id cannot be empty.');
    }

    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.trim().isEmpty) {
      throw StateError('You must be signed in to delete categories.');
    }

    await _userCategories(uid).doc(id).delete();
  }
}
