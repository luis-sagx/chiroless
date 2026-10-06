import 'package:financial_control/features/analytics/presentation/widgets/monthly_trend_chart.dart';
import 'package:financial_control/features/analytics/presentation/widgets/budget_pace_chart.dart';
import 'package:financial_control/features/transactions/data/transaction_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('La tendencia permite elegir un rango aun sin movimientos', (
    tester,
  ) async {
    int? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MonthlyTrendChart(
            data: const [],
            months: 6,
            onMonthsChanged: (months) => selected = months,
          ),
        ),
      ),
    );

    expect(find.text('Aún no hay movimientos en este periodo'), findsOneWidget);
    await tester.tap(find.text('6 meses'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('12 meses').last);
    await tester.pumpAndSettle();
    expect(selected, 12);
  });

  testWidgets('El ritmo muestra dias espaciados y oculta el extremo final', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: BudgetPaceChart(expenses: [], budgetLimit: 100)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('5'), findsOneWidget);
    expect(find.text('10'), findsOneWidget);
    final now = DateTime.now();
    final lastDay = DateTime(now.year, now.month + 1, 0).day;
    expect(find.text('$lastDay'), findsNothing);
  });

  testWidgets('La tendencia muestra meses del rango elegido', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MonthlyTrendChart(
            data: [
              MonthTotals(month: '2026-08', income: 30, expense: 10),
              MonthTotals(month: '2026-09', income: 20, expense: 15),
              MonthTotals(month: '2026-10', income: 40, expense: 5),
            ],
            months: 3,
            onMonthsChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ago'), findsOneWidget);
    expect(find.text('Sep'), findsOneWidget);
    expect(find.text('Oct'), findsOneWidget);
  });
}
