import 'dart:async';
// Firestore seals its client types; this test-only double avoids platform calls
// and exercises our read/write contract without adding a runtime dependency.
// ignore_for_file: subtype_of_sealed_class
import 'package:cloud_firestore/cloud_firestore.dart';

/// A local transactional store. Writes are staged and discarded on failure.
class MemoryFirestore extends FakeFirestore {
  final documents = <String, Map<String, dynamic>>{};
  bool failCommit = false;
  Future<void> _tail = Future.value();

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      MemoryCollection(this, path);

  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> transactionHandler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) async {
    final previous = _tail;
    // Serialize callbacks to model Firestore retrying conflicting user writes.
    final completer = Completer<void>();
    _tail = completer.future;
    await previous;
    try {
      final transaction = MemoryTransaction(this);
      final result = await transactionHandler(transaction);
      if (failCommit) throw StateError('commit failed');
      documents.addAll(transaction.pending);
      return result;
    } finally {
      completer.complete();
    }
  }
}

class FakeFirestore implements FirebaseFirestore {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MemoryCollection implements CollectionReference<Map<String, dynamic>> {
  final MemoryFirestore store;
  @override
  final String path;
  final Map<String, Object?> filters;
  final int? maximum;
  MemoryCollection(
    this.store,
    this.path, [
    this.filters = const {},
    this.maximum,
  ]);
  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) =>
      MemoryDocument(store, '${this.path}/$path');
  @override
  Query<Map<String, dynamic>> where(
    Object field, {
    Object? isEqualTo,
    Object? isNotEqualTo,
    Object? isLessThan,
    Object? isLessThanOrEqualTo,
    Object? isGreaterThan,
    Object? isGreaterThanOrEqualTo,
    Object? arrayContains,
    Iterable<Object?>? arrayContainsAny,
    Iterable<Object?>? whereIn,
    Iterable<Object?>? whereNotIn,
    bool? isNull,
  }) => MemoryCollection(store, path, {
    ...filters,
    field.toString(): isEqualTo,
  }, maximum);
  @override
  Query<Map<String, dynamic>> limit(int limit) =>
      MemoryCollection(store, path, filters, limit);
  @override
  Query<Map<String, dynamic>> orderBy(
    Object field, {
    bool descending = false,
  }) => this;
  @override
  Future<QuerySnapshot<Map<String, dynamic>>> get([GetOptions? options]) async {
    final values = store.documents.entries.where(
      (entry) =>
          entry.key.startsWith('$path/') &&
          filters.entries.every(
            (filter) => entry.value[filter.key] == filter.value,
          ),
    );
    return MemoryQuerySnapshot(
      values
          .take(maximum ?? values.length)
          .map((entry) => MemoryQueryDocument(entry.key, entry.value))
          .toList(),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MemoryDocument implements DocumentReference<Map<String, dynamic>> {
  final MemoryFirestore store;
  @override
  final String path;
  MemoryDocument(this.store, this.path);
  @override
  String get id => path.split('/').last;
  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async => MemorySnapshot(path, store.documents[path]);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MemoryTransaction implements Transaction {
  final MemoryFirestore store;
  final pending = <String, Map<String, dynamic>>{};
  MemoryTransaction(this.store);
  @override
  Future<DocumentSnapshot<T>> get<T extends Object?>(
    DocumentReference<T> reference,
  ) async =>
      MemorySnapshot(reference.path, store.documents[reference.path])
          as DocumentSnapshot<T>;
  @override
  Transaction update(DocumentReference reference, Map<Object, Object?> data) {
    pending[reference.path] = {
      ...?store.documents[reference.path],
      ...data.map((key, value) => MapEntry(key.toString(), value)),
    };
    return this;
  }

  @override
  Transaction set<T>(
    DocumentReference<T> reference,
    T data, [
    SetOptions? options,
  ]) {
    pending[reference.path] = {
      ...?store.documents[reference.path],
      ...(data as Map<String, dynamic>),
    };
    return this;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MemorySnapshot implements DocumentSnapshot<Map<String, dynamic>> {
  @override
  final String id;
  final Map<String, dynamic>? value;
  MemorySnapshot(String path, this.value) : id = path.split('/').last;
  @override
  bool get exists => value != null;
  @override
  Map<String, dynamic>? data() => value == null ? null : Map.of(value!);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MemoryQueryDocument extends MemorySnapshot
    implements QueryDocumentSnapshot<Map<String, dynamic>> {
  MemoryQueryDocument(super.path, Map<String, dynamic> super.value);
  @override
  Map<String, dynamic> data() => super.data()!;
}

class MemoryQuerySnapshot implements QuerySnapshot<Map<String, dynamic>> {
  @override
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  MemoryQuerySnapshot(this.docs);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
