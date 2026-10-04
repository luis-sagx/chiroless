# Plan de mejoras: registro rápido, arranque instantáneo y gamificación correcta

> **Audiencia de este documento:** un agente ejecutor que va a aplicar los cambios paso a paso.
> **Regla de oro:** NO improvises. Cada tarea dice exactamente qué archivo tocar y qué hacer.
> Si algo no coincide con lo descrito (línea movida, nombre distinto), busca el código por su contenido, no por el número de línea.

---

## 0. Contexto del proyecto

- App Flutter (`financial_control`, mostrada como "Sagx UP") de control de gastos personales con Firebase (Auth + Firestore).
- Estructura: `lib/features/<feature>/data/*_service.dart` (servicios) y `lib/features/<feature>/presentation/pages/*.dart` (UI). Modelos en `lib/models/`.
- Colecciones Firestore: `users`, `expenses`, `incomes`, `budgets`, `achievements`.
- Los documentos de `expenses` e `incomes` tienen campo `month` con formato `"YYYY-MM"` (ej. `"2026-07"`). **Importante:** `TransactionService.getUserExpenses(userId)` y `getUserIncomes(userId)` SIN parámetro `month` devuelven SOLO el mes actual (filtran por `month`), no todo el historial.
- El doc de `users` tiene campos `points` (int) y `level` (String).
- La persistencia offline de Firestore está activa por defecto en Android/iOS: las escrituras se guardan localmente al instante y se sincronizan solas. **PERO** el `Future` de `collection.add(...)` solo se completa cuando el servidor confirma → nunca bloquees la UI esperándolo si quieres UX instantánea.

### Reglas para el agente ejecutor

1. Ejecuta las fases **en orden**: 1 → 2 → 3 → 4.
2. Al terminar cada fase: correr `flutter analyze` y arreglar cualquier error nuevo antes de seguir.
3. Un commit por fase, con el mensaje indicado al final de cada fase. No commitear `pubspec.lock` si solo cambió por side-effect.
4. No renombres archivos, clases ni métodos existentes salvo que la tarea lo pida.
5. No cambies estilos/colores/tema salvo lo especificado.
6. Los snippets de este plan son la especificación: adáptalos a imports/nombres reales del archivo, pero no cambies su lógica.
7. `print` para errores está bien (es el patrón del proyecto).

---

## FASE 1 — Registro ultra-rápido de gastos e ingresos

**Objetivo:** registrar un gasto en ~3 taps y <2 segundos: tap en "+" → escribir monto (teclado ya abierto) → tap en categoría → tap "Guardar". La pantalla se cierra al instante; puntos/logros/notificaciones corren en segundo plano.

### Tarea 1.1 — Crear punto de entrada único para recompensas en background

**Archivo:** `lib/features/achievements/data/gamification_service.dart`

Agregar este método público a `GamificationService` (las funciones que usa ya existen o se crean en la Fase 3; por ahora llama a las existentes):

```dart
/// Punto de entrada único post-transacción. Se llama SIN await desde la UI.
/// Nunca lanza excepciones (todo el servicio ya atrapa errores internamente).
Future<void> onTransactionRegistered(
  String userId, {
  required bool isExpense,
}) async {
  await awardPointsForTransaction(userId, isExpense: isExpense);
  await checkAndUnlockAchievements(userId);
}
```

> Nota: en la Fase 3 este método se modificará (puntos unificados + racha). En esta fase solo centraliza las llamadadas existentes.

### Tarea 1.2 — Crear el bottom sheet de registro rápido

**Archivo NUEVO:** `lib/features/transactions/presentation/widgets/quick_add_sheet.dart`

Crear un `StatefulWidget` llamado `QuickAddSheet` con esta especificación exacta:

**Contenido visual (de arriba a abajo):**
1. Handle gris (barra de 40×4, igual al de `_showAddTransactionOptions` en `home_page.dart`).
2. Toggle de dos segmentos: **"Gasto"** (seleccionado por defecto) / **"Ingreso"**. Usar dos `ChoiceChip` o un `SegmentedButton<bool>`. Color gasto: `AppTheme.accentColor`, color ingreso: `AppTheme.secondaryColor`.
3. Campo de monto: `TextFormField` con `autofocus: true`, `keyboardType: TextInputType.numberWithOptions(decimal: true)`, fuente grande (32, bold), prefijo `$`, hint `0.00`. **`autofocus: true` es obligatorio** — es lo que abre el teclado al instante.
4. Chips de categoría en `Wrap` (spacing 8): si es Gasto, usar la lista `_categories` de `add_expense_page.dart` (`'Alimentación', 'Transporte', 'Entretenimiento', 'Salud', 'Educación', 'Vivienda', 'Ropa', 'Servicios', 'Otros'`); si es Ingreso, la lista `_sources` de `add_income_page.dart` (`'Salario', 'Freelance', 'Negocio', 'Inversiones', 'Regalo', 'Beca', 'Padres', 'Otros'`). Primera opción seleccionada por defecto. Al cambiar el toggle, resetear la categoría a la primera de la nueva lista.
5. Botón principal ancho completo: **"Guardar"**.
6. Debajo, un `TextButton` pequeño: **"Más opciones"** → cierra el sheet y navega a `AddExpensePage` o `AddIncomePage` según el toggle.

**NO incluir:** fecha (siempre `DateTime.now()`), descripción (siempre `''`), checkbox de impulsivo (siempre `false`). Eso vive en las páginas completas ("Más opciones").

**Lógica de guardado (crítica — así se logra la UX instantánea):**

```dart
void _save() {
  final amount = double.tryParse(_amountController.text.replaceAll(',', '.'));
  if (amount == null || amount <= 0) {
    setState(() => _error = 'Monto inválido');
    return;
  }
  final user = FirebaseService().currentUser;
  if (user == null) return;

  if (_isExpense) {
    final expense = Expense(
      id: null,
      userId: user.uid,
      amount: amount,
      category: _selectedCategory,
      description: '',
      date: DateTime.now(),
      isImpulsive: false,
    );
    // SIN await: la persistencia offline de Firestore garantiza la escritura.
    unawaited(_transactionService.createExpense(expense));
    unawaited(
      _gamificationService.onTransactionRegistered(user.uid, isExpense: true),
    );
    Navigator.pop(context, QuickAddResult(isExpense: true, amount: amount));
  } else {
    final income = Income(
      id: null,
      userId: user.uid,
      amount: amount,
      source: _selectedCategory,
      description: '',
      date: DateTime.now(),
    );
    unawaited(_transactionService.createIncome(income));
    unawaited(
      _gamificationService.onTransactionRegistered(user.uid, isExpense: false),
    );
    Navigator.pop(context, QuickAddResult(isExpense: false, amount: amount));
  }
}
```

- `unawaited` viene de `dart:async` (`import 'dart:async';`).
- Definir en el mismo archivo la clase resultado:

```dart
class QuickAddResult {
  final bool isExpense;
  final double amount;
  QuickAddResult({required this.isExpense, required this.amount});
}
```

- El sheet debe mostrarse con `showModalBottomSheet(isScrollControlled: true, ...)` y envolver el contenido en `Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom))` para que el teclado no lo tape.
- Revisar los constructores reales de `Expense` (`lib/models/expense_model.dart`) e `Income` (`lib/models/income_model.dart`) y ajustar parámetros si difieren del snippet.

### Tarea 1.3 — Conectar el sheet al botón central del home

**Archivo:** `lib/features/home/presentation/pages/home_page.dart`

1. Reemplazar el **cuerpo completo** del método `_showAddTransactionOptions(BuildContext context)` por:

```dart
void _showAddTransactionOptions(BuildContext context) async {
  final result = await showModalBottomSheet<QuickAddResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => const QuickAddSheet(),
  );
  if (result != null && mounted) {
    _applyOptimisticTransaction(result);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.isExpense ? 'Gasto guardado' : 'Ingreso guardado'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
```

2. Agregar el método de actualización optimista (NO recargar de Firestore: la escritura puede seguir pendiente de confirmación del servidor y una lectura al servidor no la incluiría):

```dart
void _applyOptimisticTransaction(QuickAddResult result) {
  setState(() {
    if (result.isExpense) {
      totalExpense += result.amount;
      totalBalance -= result.amount;
    } else {
      totalIncome += result.amount;
      totalBalance += result.amount;
    }
  });
}
```

3. Los "Quick Actions" del home ("Agregar Ingreso" / "Agregar Gasto") siguen navegando a las páginas completas — no tocarlos.
4. Agregar el import de `quick_add_sheet.dart`.

### Tarea 1.4 — Quitar el bloqueo en las páginas completas

**Archivo:** `lib/features/transactions/presentation/pages/add_expense_page.dart`, método `_saveExpense()`

Hoy el flujo espera (en serie) crear gasto → puntos → logros → presupuesto → notificaciones antes de cerrar. Cambiar a:

1. Mantener `await _transactionService.createExpense(expense);` (feedback de error aquí es aceptable).
2. **Todo lo demás** (los dos llamados a `_gamificationService` Y el bloque completo de "Notificaciones Inteligentes" con `_budgetService.getBudgetStatus` + `showNotification`) se mueve a un método privado `Future<void> _postSaveTasks(String userId, double amount)` y se invoca **sin await**, justo antes del snackbar:

```dart
await _transactionService.createExpense(expense);
unawaited(_postSaveTasks(user.uid, expense.amount));
if (mounted) {
  // snackbar + Navigator.pop(context, true)  (código existente, sin cambios)
}
```

3. Dentro de `_postSaveTasks`, reemplazar los dos llamados de gamificación por uno solo: `await _gamificationService.onTransactionRegistered(userId, isExpense: true);` y conservar la lógica de notificaciones de presupuesto tal cual (usando el parámetro `amount` en lugar de `_amountController.text`, porque el controller puede estar disposed cuando corra el background).
4. `import 'dart:async';` para `unawaited`.

**Archivo:** `lib/features/transactions/presentation/pages/add_income_page.dart`, método `_saveIncome()`

Igual: mantener `await createIncome(...)`, reemplazar los dos llamados de gamificación por `unawaited(_gamificationService.onTransactionRegistered(user.uid, isExpense: false));` y cerrar de inmediato.

### Criterios de aceptación Fase 1

- [ ] Tap en botón central "+" abre el sheet con el teclado numérico YA visible.
- [ ] Monto + tap en chip + "Guardar" cierra el sheet en <500 ms (sin spinner) y el balance del home se actualiza al instante.
- [ ] En modo avión: guardar funciona igual de rápido y la transacción aparece en Firestore al recuperar conexión.
- [ ] "Más opciones" abre la página completa correspondiente.
- [ ] Guardar desde las páginas completas cierra la pantalla apenas se crea la transacción.
- [ ] `flutter analyze` sin errores nuevos.

**Commit:** `feat: quick add sheet y guardado no bloqueante de transacciones`

---

## FASE 2 — Arranque casi instantáneo

**Objetivo:** de icono a home en ~1 segundo. Hoy: `main()` espera notificaciones antes de `runApp` + el splash tiene 3 s de delay fijo + animación de 2 s.

### Tarea 2.1 — No bloquear `main()` con notificaciones

**Archivo:** `lib/main.dart`

Reemplazar `main()` por:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Imprescindibles antes del primer frame (ambos son rápidos):
  await EnvConfig.load();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const MyApp());

  // Notificaciones: NO bloquean el arranque.
  unawaited(_initNotifications());
}

Future<void> _initNotifications() async {
  try {
    await NotificationService().init();
    await NotificationService().scheduleDailyReminder();
  } catch (e) {
    print('Error inicializando notificaciones: $e');
  }
}
```

- `import 'dart:async';` para `unawaited`.
- **NO** mover `EnvConfig.load()` a background: `home_page.dart` lee `dotenv.env['ADMIN_EMAIL']` en el build del perfil y `flutter_dotenv` lanza excepción si se accede antes de `load()`. Cargar el `.env` toma milisegundos.

### Tarea 2.2 — Eliminar los 3 segundos fijos del splash

**Archivo:** `lib/features/home/presentation/pages/splash_screen.dart`

1. Cambiar la duración del `AnimationController` de `Duration(seconds: 2)` a `Duration(milliseconds: 700)`.
2. Eliminar por completo el bloque:

```dart
Future.delayed(const Duration(seconds: 3), () {
  _checkAuthAndNavigate();
});
```

3. En su lugar, navegar cuando termine la animación:

```dart
_controller.forward().whenComplete(() {
  if (mounted) _checkAuthAndNavigate();
});
```

4. En `_checkAuthAndNavigate`, proteger el uso de `context` tras el async gap: agregar `if (!mounted) return;` como primera línea.

### Tarea 2.3 — Cargar el home en una sola pasada paralela

**Archivo:** `lib/features/home/presentation/pages/home_page.dart`

Hoy `_loadTransactionData()` hace 3 llamadas en serie y `getMonthSummary` internamente vuelve a bajar gastos e ingresos (los mismos datos se descargan dos veces). Reemplazar el cuerpo del `try` de `_loadTransactionData()` por una sola pasada:

```dart
final results = await Future.wait([
  transactionService.getUserExpenses(user.uid),
  transactionService.getUserIncomes(user.uid),
]);
final expenses = results[0] as List<Expense>;
final incomes = results[1] as List<Income>;

final totalExpenses =
    expenses.fold<double>(0, (sum, e) => sum + e.amount);
final totalIncomes =
    incomes.fold<double>(0, (sum, i) => sum + i.amount);

final List<dynamic> combined = [...expenses, ...incomes];
combined.sort((a, b) => b.date.compareTo(a.date));

if (mounted) {
  setState(() {
    totalBalance = totalIncomes - totalExpenses;
    totalIncome = totalIncomes;
    totalExpense = totalExpenses;
    recentTransactions = combined.take(5).toList();
    isLoadingTransactions = false;
  });
}
```

- Eliminar el llamado a `getMonthSummary`. Agregar import de `income_model.dart` si falta.
- Además, en `_loadUser()`: hoy espera `getUser` y LUEGO carga transacciones. Cambiar para que ambas corran en paralelo (lanzar `_loadTransactionData()` sin await al inicio de `_loadUser`, o usar `Future.wait`).

### Criterios de aceptación Fase 2

- [ ] Tiempo de icono → home (usuario ya logueado) ≈ 1 s en dispositivo real (antes ~5 s).
- [ ] Las notificaciones diarias (13:00 y 20:00) se siguen programando (verificar con log o breakpoint en `_initNotifications`).
- [ ] Home muestra balance y transacciones correctos.
- [ ] `flutter analyze` sin errores nuevos.

**Commit:** `perf: arranque no bloqueante, splash corto y carga paralela del home`

---

## FASE 3 — Gamificación correcta

**Objetivo:** eliminar el doble conteo de puntos, arreglar rachas y premios triviales, y que el progreso mostrado sea exacto.

### Bugs que esta fase corrige (para entender el porqué)

| # | Bug | Dónde |
|---|-----|-------|
| 1 | Al crear un logro nuevo se guarda SIN `unlockedAt`, así que el siguiente check lo "desbloquea" otra vez y **suma los puntos dos veces** | `gamification_service.dart`, rama `else` de `checkAndUnlockAchievements` |
| 2 | `_addPoints` hace leer-modificar-escribir sin transacción → carreras pierden/duplican puntos | `gamification_service.dart` |
| 3 | La racha solo mira el mes actual → se rompe al cruzar de mes | `_checkStreakDays` |
| 4 | "Presupuesto cumplido" se desbloquea con solo tener presupuesto sin excederlo hoy (no un mes completo) | `checkAndUnlockAchievements`, case `'budget'` |
| 5 | "Control total" y "Ahorrador novato" se desbloquean con 1 sola transacción | cases `'milestone'` y `'savings'` |
| 6 | Dos sistemas de puntos: `awardPointsForTransaction` (10/15 hardcoded) vs `AppConstants` (5/5, sin uso real) | servicio + `app_constants.dart` |
| 7 | El "Sincronizar Puntos" (backfill) cuenta SOLO el mes actual y SOBRESCRIBE los puntos → borra historial | `lib/utils/backfill_points.dart` |
| 8 | Barra de progreso de nivel usa `puntos/techo` en vez de progreso relativo al nivel | `achievements_page.dart` |
| 9 | Los logros "Por desbloquear" casi nunca se muestran (solo existen docs de logros ya desbloqueados) | `achievements_page.dart` |

### Tarea 3.1 — Unificar valores de puntos en `AppConstants`

**Archivo:** `lib/core/constants/app_constants.dart`

Cambiar a los valores reales en uso:

```dart
static const int pointsPerExpenseRegistered = 10;
static const int pointsPerIncomeRegistered = 15;
```

(dejar `pointsPerBudgetCompliance` y `pointsPerAchievementUnlocked` como están; no se usan para sumar directamente).

**Archivo:** `lib/features/achievements/data/gamification_service.dart`

- **Eliminar** el método `awardPointsForTransaction` completo.
- En `onTransactionRegistered` (creado en Fase 1), reemplazar el llamado a `awardPointsForTransaction` por:

```dart
await rewardAction(userId, isExpense ? 'expense_registered' : 'income_registered');
await _updateStreak(userId);            // se crea en la Tarea 3.3
await checkAndUnlockAchievements(userId);
```

- Verificar con grep que no queden otros usos de `awardPointsForTransaction` (había en `add_expense_page.dart` y `add_income_page.dart`; la Fase 1 ya los reemplazó por `onTransactionRegistered`).

### Tarea 3.2 — Puntos atómicos con transacción Firestore

**Archivo:** `lib/features/achievements/data/gamification_service.dart`

Reemplazar el cuerpo de `_addPoints` por una transacción (elimina la carrera lectura-escritura):

```dart
Future<void> _addPoints(String userId, int points) async {
  try {
    final userRef = _db.collection('users').doc(userId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(userRef);
      if (!snap.exists) return;
      final current = (snap.data()!['points'] ?? 0) as int;
      final newPoints = current + points;
      tx.update(userRef, {
        'points': newPoints,
        'level': _calculateLevel(newPoints),
      });
    });
  } catch (e) {
    print('Error agregando puntos: $e');
  }
}
```

### Tarea 3.3 — Racha persistente en el doc del usuario (arregla cruce de mes)

**Archivo:** `lib/features/achievements/data/gamification_service.dart`

1. Agregar método privado `_updateStreak` (se llama en cada transacción registrada, desde `onTransactionRegistered`):

```dart
/// Mantiene 'currentStreak' y 'lastTxDate' (formato 'YYYY-MM-DD') en users/{uid}.
Future<void> _updateStreak(String userId) async {
  try {
    final userRef = _db.collection('users').doc(userId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(userRef);
      if (!snap.exists) return;
      final data = snap.data()!;
      final now = DateTime.now();
      final today =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final yest = now.subtract(const Duration(days: 1));
      final yesterday =
          '${yest.year}-${yest.month.toString().padLeft(2, '0')}-${yest.day.toString().padLeft(2, '0')}';

      final lastTxDate = data['lastTxDate'] as String?;
      final currentStreak = (data['currentStreak'] ?? 0) as int;

      if (lastTxDate == today) return; // ya contó hoy
      final newStreak = (lastTxDate == yesterday) ? currentStreak + 1 : 1;
      tx.update(userRef, {'currentStreak': newStreak, 'lastTxDate': today});
    });
  } catch (e) {
    print('Error actualizando racha: $e');
  }
}
```

2. **Eliminar** el método `_checkStreakDays` completo.
3. En `checkAndUnlockAchievements`, el case `'streak'` pasa a leer el valor persistido. Como el user doc igual se necesita, leerlo UNA vez al inicio del método (antes del loop de templates):

```dart
final userSnap = await _db.collection('users').doc(userId).get();
final userData = userSnap.data() ?? {};
final currentStreak = (userData['currentStreak'] ?? 0) as int;
```

y en el case: `shouldUnlock = currentStreak >= 7;`

> Nota: usuarios existentes empiezan con racha 0 desde el deploy. Aceptable — hoy la racha está rota de todos modos.

### Tarea 3.4 — IDs determinísticos y `unlockedAt` desde el inicio (arregla doble conteo)

**Archivo:** `lib/models/achievement_model.dart`

Agregar campo `'key'` a cada template de `AchievementTemplates.templates`:

| title | key |
|---|---|
| Primera transacción | `first_transaction` |
| Racha de 7 días | `streak_7` |
| Presupuesto cumplido | `budget_month` |
| Ahorrador novato | `savings_10` |
| Control total | `control_impulse` |

**Archivo:** `lib/features/achievements/data/gamification_service.dart`, en `checkAndUnlockAchievements`, reemplazar TODO el bloque `if (shouldUnlock) { ... }` por:

```dart
if (shouldUnlock) {
  final key = template['key'] as String;
  final docId = '${userId}_$key';
  final achievement = Achievement(
    id: docId,
    userId: userId,
    title: title,
    description: template['description'] as String,
    icon: template['icon'] as String,
    points: template['points'] as int,
    category: template['category'] as String,
    unlockedAt: DateTime.now(), // CRÍTICO: se crea YA desbloqueado
  );
  // set con ID determinístico: idempotente, imposible duplicar el logro
  await _db
      .collection('achievements')
      .doc(docId)
      .set(achievement.toMap(), SetOptions(merge: true));
  unlockedAchievements.add(achievement);
  await _addPoints(userId, template['points'] as int);
}
```

Además:

- El "skip si ya desbloqueado" existente (`if (existingAchievement != null && existingAchievement.unlockedAt != null) continue;`) se queda tal cual: es lo que evita re-otorgar.
- **Caso legado:** puede haber docs viejos con `unlockedAt: null` (creados por el bug). Para ellos `existingAchievement != null && unlockedAt == null` → el flujo de arriba les hará `set(merge)` poniendo `unlockedAt`, pero como son docs con ID aleatorio de `add()`, quedará un doc duplicado con ID determinístico. Solución simple: al inicio del loop, si `existingAchievement != null && existingAchievement.unlockedAt == null`, borrar ese doc legado antes de continuar:

```dart
if (existingAchievement != null && existingAchievement.unlockedAt == null) {
  await _db.collection('achievements').doc(existingAchievement.id).delete();
}
```

(y NO volver a sumar puntos por él: el flujo normal de `shouldUnlock` decidirá si se desbloquea limpio. Sí, esto puede regalar el desbloqueo "limpio" una vez; es la migración aceptada.)

### Tarea 3.5 — Redefinir los logros triviales

**Archivo:** `lib/features/achievements/data/gamification_service.dart`, dentro del `switch (template['category'])` de `checkAndUnlockAchievements`:

1. **`Presupuesto cumplido`** (case `'budget'`): evaluar el **mes anterior**, no el actual. Reemplazar la lógica por:

```dart
final now = DateTime.now();
final prev = DateTime(now.year, now.month - 1, 1);
final prevMonth = '${prev.year}-${prev.month.toString().padLeft(2, '0')}';
final prevBudget = await _budgetService.getBudgetByMonth(userId, prevMonth);
if (prevBudget != null) {
  final prevExpenses =
      await _transactionService.getUserExpenses(userId, month: prevMonth);
  final spent = prevExpenses.fold<double>(0, (s, e) => s + e.amount);
  shouldUnlock = spent <= prevBudget.monthlyLimit;
}
```

(`getBudgetByMonth` ya existe en `budget_service.dart`. Con esto, el `budgetStatus` que se obtiene al inicio del método ya no se usa para logros: **eliminar** la línea `final budgetStatus = await _budgetService.getBudgetStatus(userId);` si nadie más la usa dentro del método.)

2. **`Control total`** (case `'milestone'`): exigir volumen mínimo. Cambiar la condición final a:

```dart
shouldUnlock = expenses.length >= 10 && impulsivePercentage < 20;
```

3. **`Ahorrador novato`** (case `'savings'`): exigir actividad real. Cambiar la condición final a:

```dart
shouldUnlock =
    incomes.isNotEmpty && expenses.length >= 5 && savingsPercentage >= 10;
```

4. Actualizar las `description` de esos 3 templates en `achievement_model.dart` para que digan lo que realmente miden:
   - Presupuesto cumplido: `'Cerraste un mes sin exceder tu presupuesto'`
   - Control total: `'Con 10+ gastos registrados, mantuviste los impulsivos bajo 20%'`
   - Ahorrador novato: `'Ahorraste al menos 10% de tus ingresos del mes (mín. 5 gastos)'`

> Nota consciente: `expenses`/`incomes` dentro de este método siguen siendo del mes actual (así funciona `getUserExpenses` sin `month`). Eso ahora es **correcto**: estos logros se evalúan sobre el mes en curso y quedan permanentes al desbloquearse.

### Tarea 3.6 — Eliminar el backfill (peligroso: sobrescribe puntos con datos del mes actual)

1. **Borrar** el archivo `lib/utils/backfill_points.dart`.
2. **Borrar** el método `backfillPoints` de `gamification_service.dart`.
3. **Archivo:** `lib/features/achievements/presentation/pages/achievements_page.dart`:
   - Borrar el import de `backfill_points.dart`, el campo `_backfillUtility`, el campo `_isBackfilling`, el método `_backfillPoints()` completo, y el bloque UI entero que empieza con `// Sync Points Button (only show if points are 0)` (`if (_userPoints == 0) ...[ ... ]`).

### Tarea 3.7 — Arreglar barra de progreso de nivel

**Archivo:** `lib/features/achievements/data/gamification_service.dart`

Agregar método:

```dart
/// Puntos mínimos del nivel actual (piso del nivel numérico).
int pointsForCurrentLevel(int level) {
  switch (level) {
    case 1: return 0;
    case 2: return 150;
    case 3: return 300;
    case 4: return 500;
    case 5: return 750;
    default: return 1000;
  }
}
```

**Archivo:** `lib/features/achievements/presentation/pages/achievements_page.dart`

1. En `_loadData()`, guardar también el piso: `_currentLevelPoints = _gamificationService.pointsForCurrentLevel(level);` (nuevo campo `int _currentLevelPoints = 0;`).
2. En el `LinearProgressIndicator`, cambiar `value: _userPoints / _nextLevelPoints` por:

```dart
value: ((_userPoints - _currentLevelPoints) /
        (_nextLevelPoints - _currentLevelPoints))
    .clamp(0.0, 1.0),
```

3. En el texto `'$_userPoints / $_nextLevelPoints'` no hace falta cambio.

### Tarea 3.8 — Mostrar logros bloqueados desde los templates

**Archivo:** `lib/features/achievements/presentation/pages/achievements_page.dart`

En Firestore solo existen docs de logros desbloqueados (tras la Tarea 3.4), así que "Por Desbloquear" quedaría vacío. Arreglo: construir los bloqueados en memoria desde `AchievementTemplates.templates`.

En el `build`, reemplazar el cálculo de `lockedAchievements` por:

```dart
final unlockedTitles = unlockedAchievements.map((a) => a.title).toSet();
final lockedAchievements = AchievementTemplates.templates
    .where((t) => !unlockedTitles.contains(t['title']))
    .map((t) => Achievement(
          userId: '',
          title: t['title'] as String,
          description: t['description'] as String,
          icon: t['icon'] as String,
          points: t['points'] as int,
          category: t['category'] as String,
        ))
    .toList();
```

(agregar import de `achievement_model.dart` si falta; ya está importado). Eliminar el filtro anterior `_achievements.where((a) => !a.isUnlocked)`. El "Empty State" (`_achievements.isEmpty`) ya casi nunca aplicará; cambiar su condición a `unlockedAchievements.isEmpty && lockedAchievements.isEmpty` o eliminarlo.

### Criterios de aceptación Fase 3

- [ ] Registrar 1 gasto suma exactamente 10 pts (una vez). Registrar otro → +10. Ver doc `users/{uid}` en Firestore.
- [ ] "Primera transacción" se desbloquea una sola vez, con `unlockedAt` no nulo, doc con ID `{uid}_first_transaction`, y suma sus 10 pts una sola vez (verificar que un segundo guardado NO vuelva a sumar los puntos del logro).
- [ ] `users/{uid}` tiene `currentStreak` y `lastTxDate` tras registrar; registrar dos veces el mismo día no incrementa la racha.
- [ ] "Presupuesto cumplido" NO se desbloquea al crear un presupuesto nuevo.
- [ ] Pestaña Logros: barra de progreso correcta (ej. 200 pts en nivel 2 → 33%, no 66%) y sección "Por Desbloquear" muestra los templates restantes.
- [ ] Ya no existe el botón "Sincronizar Puntos".
- [ ] `flutter analyze` sin errores nuevos y `grep -rn "awardPointsForTransaction\|backfill" lib/` sin resultados.

**Commit:** `fix: gamificación — puntos atómicos, logros idempotentes, racha persistente`

---

## FASE 4 — Verificación final

1. `flutter analyze` → 0 errores.
2. `flutter test` → si hay tests que fallaban ANTES de estos cambios, documentarlo; no deben fallar tests nuevos por estos cambios.
3. Prueba manual completa en dispositivo/emulador:
   - Arranque frío → home en ~1 s.
   - Botón "+" → registrar gasto en 3 taps, sheet se cierra al instante, balance se actualiza.
   - Registrar ingreso por el sheet.
   - Modo avión → registrar gasto → funciona; reconectar → aparece en Firestore.
   - Pestaña Logros: puntos correctos, logros coherentes.
   - Verificar en Firebase Console: sin docs duplicados en `achievements`, puntos exactos en `users`.
4. Actualizar `ARCHITECTURE.md` si describe el flujo de gamificación o el arranque (revisar y ajustar las secciones afectadas).

**Commit final:** `docs: actualizar arquitectura tras mejoras de UX y gamificación`

---

## Resumen de archivos afectados

| Archivo | Acción |
|---|---|
| `lib/features/transactions/presentation/widgets/quick_add_sheet.dart` | **CREAR** |
| `lib/features/home/presentation/pages/home_page.dart` | Modificar (sheet + optimistic + carga paralela) |
| `lib/features/transactions/presentation/pages/add_expense_page.dart` | Modificar (guardado no bloqueante) |
| `lib/features/transactions/presentation/pages/add_income_page.dart` | Modificar (guardado no bloqueante) |
| `lib/main.dart` | Modificar (notificaciones en background) |
| `lib/features/home/presentation/pages/splash_screen.dart` | Modificar (sin delay fijo) |
| `lib/features/achievements/data/gamification_service.dart` | Modificar (núcleo de la Fase 3) |
| `lib/models/achievement_model.dart` | Modificar (keys + descripciones) |
| `lib/core/constants/app_constants.dart` | Modificar (valores de puntos) |
| `lib/features/achievements/presentation/pages/achievements_page.dart` | Modificar (progreso, bloqueados, sin backfill) |
| `lib/utils/backfill_points.dart` | **BORRAR** |
