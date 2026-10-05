import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Puente con el widget Android de pantalla de inicio (MethodChannel nativo).
/// Nunca lanza: si el widget falla, la app sigue igual.
class HomeWidgetService {
  static const _channel = MethodChannel('chiroless/widget');

  static bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Datos que muestra el widget. Requiere initializeDateFormatting('es').
  static Map<String, Object> buildPayload(
    double spent,
    double? limit,
    DateTime now,
  ) {
    final month = DateFormat('MMMM', 'es').format(now);
    final hasBudget = limit != null && limit > 0;
    final percent = hasBudget ? (spent / limit * 100).round() : -1;
    return {
      'month': month[0].toUpperCase() + month.substring(1),
      'spent': '\$${spent.toStringAsFixed(2)}',
      'percent': percent,
      'budget_line': hasBudget
          ? '$percent% de \$${limit.toStringAsFixed(0)}'
          : '',
    };
  }

  static Future<void> update({
    required double spent,
    double? limit,
    DateTime? now,
  }) => _call('update', buildPayload(spent, limit, now ?? DateTime.now()));

  static Future<void> clear() => _call('clear');

  static Future<void> setHidden(bool hidden) => _call('setHidden', hidden);

  static Future<bool> isHidden() async =>
      await _call<bool>('isHidden') ?? false;

  static Future<T?> _call<T>(String method, [Object? args]) async {
    if (!_supported) return null;
    try {
      return await _channel.invokeMethod<T>(method, args);
    } on MissingPluginException {
      return null;
    } on PlatformException catch (e) {
      debugPrint('Widget: $e');
      return null;
    }
  }
}
