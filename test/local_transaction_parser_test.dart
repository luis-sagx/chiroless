import 'package:financial_control/features/transactions/data/local_transaction_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 3, 1, 10, 30);

  test('gasto simple con categoría', () {
    final d = LocalTransactionParser.parse('25 almuerzo', now: now);
    expect(d.isExpense, isTrue);
    expect(d.amount, 25.0);
    expect(d.category, 'Alimentación');
    expect(d.description, 'almuerzo');
    expect(d.date, now);
    expect(d.isComplete, isTrue);
  });

  test('decimales con punto y "ayer" cruzando de mes', () {
    final d = LocalTransactionParser.parse('pagué 12.50 uber ayer', now: now);
    expect(d.isExpense, isTrue);
    expect(d.amount, 12.5);
    expect(d.category, 'Transporte');
    expect(d.description, 'pagué uber');
    expect(d.date, DateTime(2026, 2, 28, 10, 30));
  });

  test('decimales con coma', () {
    final d = LocalTransactionParser.parse('12,5 taxi', now: now);
    expect(d.amount, 12.5);
    expect(d.category, 'Transporte');
  });

  test('interpreta centavos como fracción de dólar', () {
    final d = LocalTransactionParser.parse('50 centavos', now: now);
    expect(d.amount, 0.5);
  });

  test('interpreta dólares como monto completo', () {
    final d = LocalTransactionParser.parse('50 dólares', now: now);
    expect(d.amount, 50.0);
  });

  test('interpreta dólares y centavos en una frase', () {
    final d = LocalTransactionParser.parse('1 dólar con 50 centavos', now: now);
    expect(d.amount, 1.5);
  });

  test('conserva el monto decimal sin unidad', () {
    final d = LocalTransactionParser.parse('0.5', now: now);
    expect(d.amount, 0.5);
  });

  test('no interpreta otras monedas como dólares', () {
    final d = LocalTransactionParser.parse('50 euros', now: now);
    expect(d.amount, isNull);
  });

  test('ingreso por verbo y categoría', () {
    final d = LocalTransactionParser.parse('recibí 450 sueldo', now: now);
    expect(d.isExpense, isFalse);
    expect(d.amount, 450.0);
    expect(d.category, 'Salario');
  });

  test('dinero encontrado se clasifica como ingreso en Otros', () {
    final d = LocalTransactionParser.parse('me encontré 10 dólares', now: now);
    expect(d.amount, 10.0);
    expect(d.isExpense, isFalse);
    expect(d.category, 'Otros');
    expect(d.isComplete, isTrue);
  });

  test('separador de miles y símbolo de dólar', () {
    final d = LocalTransactionParser.parse('\$1.500 arriendo', now: now);
    expect(d.amount, 1500.0);
    expect(d.category, 'Vivienda');
    expect(d.description, 'arriendo');
  });

  test('sin palabra clave: incompleto pero con palabras', () {
    const text = 'cosas varias 30';
    final d = LocalTransactionParser.parse(text, now: now);
    expect(d.amount, 30.0);
    expect(d.category, isNull);
    expect(d.isComplete, isFalse);
    expect(LocalTransactionParser.hasWords(text), isTrue);
  });

  test('solo número: sin palabras', () {
    final d = LocalTransactionParser.parse('40', now: now);
    expect(d.amount, 40.0);
    expect(d.category, isNull);
    expect(LocalTransactionParser.hasWords('40'), isFalse);
  });

  test('sin monto', () {
    final d = LocalTransactionParser.parse('netflix', now: now);
    expect(d.amount, isNull);
    expect(d.category, 'Entretenimiento');
    expect(d.isComplete, isFalse);
  });

  test('anteayer', () {
    final d = LocalTransactionParser.parse('anteayer 8 farmacia', now: now);
    expect(d.date, DateTime(2026, 2, 27, 10, 30));
    expect(d.category, 'Salud');
    expect(d.description, 'farmacia');
  });

  test('ingreso por palabra de categoría', () {
    final d = LocalTransactionParser.parse('me regalaron 20', now: now);
    expect(d.isExpense, isFalse);
    expect(d.category, 'Regalo');
  });

  test('verbo de gasto gana sobre palabra de ingreso', () {
    final d = LocalTransactionParser.parse('compré un regalo 20', now: now);
    expect(d.isExpense, isTrue);
    expect(d.amount, 20.0);
  });
}
