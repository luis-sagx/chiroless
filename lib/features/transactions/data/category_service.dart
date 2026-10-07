import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/transaction_categories.dart';

enum TransactionCategoryType { expense, income }

/// Stores each user's editable categories under their own user document.
class CategoryService {
  CategoryService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _categories(String userId) =>
      _db.collection('users').doc(userId).collection('transactionCategories');

  String _typeKey(TransactionCategoryType type) => switch (type) {
    TransactionCategoryType.expense => 'expense',
    TransactionCategoryType.income => 'income',
  };

  List<String> defaultsFor(TransactionCategoryType type) => switch (type) {
    TransactionCategoryType.expense => TransactionCategories.expenseNames,
    TransactionCategoryType.income => TransactionCategories.incomeNames,
  };

  Future<List<String>> getCategories(
    String userId,
    TransactionCategoryType type,
  ) async {
    final reference = _categories(userId).doc(_typeKey(type));
    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);
      final categories = snapshot.data()?['categories'];
      if (!snapshot.exists || categories is! Iterable || categories.isEmpty) {
        transaction.set(reference, {'categories': defaultsFor(type)});
      }
    });
    final snapshot = await reference.get();
    return _readCategories(snapshot, type);
  }

  Future<void> ensureInitialized(String userId) async {
    await Future.wait([
      getCategories(userId, TransactionCategoryType.expense),
      getCategories(userId, TransactionCategoryType.income),
    ]);
  }

  Future<List<String>> addCategory(
    String userId,
    TransactionCategoryType type,
    String rawName,
  ) async {
    final name = rawName.trim();
    if (name.isEmpty) throw ArgumentError('Escribe un nombre de categoría.');
    if (name.length > 32) {
      throw ArgumentError('La categoría puede tener máximo 32 caracteres.');
    }
    final reference = _categories(userId).doc(_typeKey(type));
    return _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);
      final current = _readCategories(snapshot, type);
      if (current.any(
        (category) => category.toLowerCase() == name.toLowerCase(),
      )) {
        throw ArgumentError('Ya existe una categoría con ese nombre.');
      }
      final updated = [...current, name];
      transaction.set(reference, {'categories': updated});
      return updated;
    });
  }

  Future<List<String>> removeCategory(
    String userId,
    TransactionCategoryType type,
    String name,
  ) {
    final reference = _categories(userId).doc(_typeKey(type));
    return _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);
      final current = _readCategories(snapshot, type);
      if (current.length <= 1) {
        throw StateError('Debe quedar al menos una categoría.');
      }
      final updated = current.where((category) => category != name).toList();
      if (updated.length == current.length) return current;
      transaction.set(reference, {'categories': updated});
      return updated;
    });
  }

  List<String> _readCategories(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    TransactionCategoryType type,
  ) {
    final values = snapshot.data()?['categories'];
    final categories = values is Iterable
        ? values.whereType<String>().map((value) => value.trim()).toList()
        : defaultsFor(type);
    final normalized = categories
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();
    return normalized.isEmpty ? defaultsFor(type) : normalized;
  }
}
