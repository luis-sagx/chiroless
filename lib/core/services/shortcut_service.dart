import 'package:flutter/foundation.dart';
import 'package:quick_actions/quick_actions.dart';

/// Accesos directos del ícono de la app. El tipo pulsado queda en [pending]
/// hasta que HomePage lo consume (puede llegar antes de que exista el home).
class ShortcutService {
  ShortcutService._();

  static const String addExpense = 'add_expense';
  static const String addIncome = 'add_income';

  static final ValueNotifier<String?> pending = ValueNotifier<String?>(null);

  static const QuickActions _quickActions = QuickActions();

  static Future<void> init() async {
    await _quickActions.initialize((type) => pending.value = type);
    await _quickActions.setShortcutItems(const [
      ShortcutItem(
        type: addExpense,
        localizedTitle: 'Nuevo gasto',
        icon: 'ic_shortcut_expense',
      ),
      ShortcutItem(
        type: addIncome,
        localizedTitle: 'Nuevo ingreso',
        icon: 'ic_shortcut_income',
      ),
    ]);
  }
}
