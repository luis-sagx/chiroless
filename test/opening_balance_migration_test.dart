import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:financial_control/features/auth/data/user_service.dart';
import 'package:financial_control/models/income_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/memory_firestore.dart';

void main() {
  late MemoryFirestore db;
  late UserService service;
  final date = DateTime(2026, 8, 3);

  setUp(() {
    db = MemoryFirestore();
    service = UserService(firestore: db);
    db.documents['users/u'] = {
      'openingBalanceAmount': 123.45,
      'openingBalanceDate': Timestamp.fromDate(date),
      'openingBalanceConfigured': true,
      'points': 140,
      'level': 'Novato',
      'currentStreak': 3,
    };
  });

  test(
    'Converts money with original date/month and preserves profile',
    () async {
      final original = Map.of(db.documents['users/u']!);
      await service.migrateOpeningBalanceToIncome('u');
      final income = Income.fromMap(
        db.documents['incomes/opening-balance-u']!,
        'opening-balance-u',
      );
      expect(income.userId, 'u');
      expect(income.amount, 123.45);
      expect(income.date, date);
      expect(income.month, '2026-08');
      expect(income.source, 'Otros');
      expect(income.description, 'Dinero inicial');
      expect(db.documents['users/u'], {
        ...original,
        'openingBalanceMigrated': true,
      });
    },
  );

  test('Concurrent clients and repeated visits create one income', () async {
    await Future.wait([
      service.migrateOpeningBalanceToIncome('u'),
      UserService(firestore: db).migrateOpeningBalanceToIncome('u'),
    ]);
    db.documents['incomes/opening-balance-u']!['amount'] = 80.0;
    await service.migrateOpeningBalanceToIncome('u');
    expect(db.documents.keys.where((key) => key.startsWith('incomes/')), [
      'incomes/opening-balance-u',
    ]);
    expect(db.documents['incomes/opening-balance-u']!['amount'], 80);
    db.documents.remove('incomes/opening-balance-u');
    await service.migrateOpeningBalanceToIncome('u');
    expect(db.documents.containsKey('incomes/opening-balance-u'), isFalse);
  });

  test('Failed commit keeps money intact and later retry converts', () async {
    db.failCommit = true;
    await expectLater(
      service.migrateOpeningBalanceToIncome('u'),
      throwsStateError,
    );
    expect(db.documents.containsKey('incomes/opening-balance-u'), isFalse);
    expect(
      db.documents['users/u']!.containsKey('openingBalanceMigrated'),
      false,
    );
    expect(db.documents['users/u']!['openingBalanceAmount'], 123.45);
    db.failCommit = false;
    await service.migrateOpeningBalanceToIncome('u');
    expect(db.documents['incomes/opening-balance-u']!['amount'], 123.45);
  });

  test(
    'Fresh, missing and zero accounts need no income or profile write',
    () async {
      db.documents['users/fresh'] = {'points': 0};
      db.documents['users/zero'] = {'openingBalanceAmount': 0};
      final before = Map.of(db.documents);
      for (final uid in ['fresh', 'zero', 'missing']) {
        await service.migrateOpeningBalanceToIncome(uid);
      }
      expect(db.documents, before);
    },
  );

  test(
    'Accepts legacy DateTime and amount even without configured flag',
    () async {
      db.documents['users/u']!['openingBalanceDate'] = date;
      db.documents['users/u']!.remove('openingBalanceConfigured');
      await service.migrateOpeningBalanceToIncome('u');
      expect(
        db.documents['incomes/opening-balance-u']!['date'],
        Timestamp.fromDate(date),
      );
    },
  );

  test(
    'Invalid amount/date fails without losing data or marking complete',
    () async {
      for (final amount in [-1, double.nan, double.infinity, '123']) {
        db.documents['users/u']!['openingBalanceAmount'] = amount;
        await expectLater(
          service.migrateOpeningBalanceToIncome('u'),
          throwsStateError,
        );
      }
      db.documents['users/u']!['openingBalanceAmount'] = 123.45;
      db.documents['users/u']!.remove('openingBalanceDate');
      await expectLater(
        service.migrateOpeningBalanceToIncome('u'),
        throwsStateError,
      );
      expect(db.documents.containsKey('incomes/opening-balance-u'), false);
      expect(
        db.documents['users/u']!.containsKey('openingBalanceMigrated'),
        false,
      );
    },
  );
}
