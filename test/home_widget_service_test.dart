import 'package:financial_control/core/services/home_widget_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  final october = DateTime(2026, 10, 4);

  test('con presupuesto calcula porcentaje y línea', () {
    final p = HomeWidgetService.buildPayload(432.5, 800, october);
    expect(p['spent'], '\$432.50');
    expect(p['percent'], 54);
    expect(p['budget_line'], '54% de \$800');
  });

  test('sin presupuesto (null o 0) usa -1 y línea vacía', () {
    for (final limit in [null, 0.0]) {
      final p = HomeWidgetService.buildPayload(10, limit, october);
      expect(p['percent'], -1);
      expect(p['budget_line'], '');
    }
  });

  test('sobre el presupuesto supera 100%', () {
    final p = HomeWidgetService.buildPayload(1200, 800, october);
    expect(p['percent'], 150);
    expect(p['budget_line'], '150% de \$800');
  });

  test('mes en español con mayúscula inicial', () {
    expect(
      HomeWidgetService.buildPayload(0, null, october)['month'],
      'Octubre',
    );
  });
}
