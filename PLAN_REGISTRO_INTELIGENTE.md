# Plan: registro inteligente (texto, voz, foto), accesos directos, gráficas claras y estilo con vida

> **Audiencia:** un agente ejecutor que aplicará los cambios paso a paso.
> **Regla de oro:** NO improvises. Cada tarea dice qué archivo tocar y qué escribir. Si una línea no coincide (número movido), busca el código **por su contenido**, no por el número de línea. Si algo del plan contradice el código real y no sabes resolverlo, **detente y pregunta al usuario**. No inventes APIs: si el analizador dice que un método no existe, abre la documentación enlazada en la tarea y no adivines.
>
> Plan escrito el 2026-10-03 sobre el árbol de trabajo de ese día. Las versiones y APIs de paquetes se verificaron en pub.dev y en la documentación de Firebase en esa fecha.
>
> **Validado antes de entregar** (en una copia del proyecto, con los comandos de este plan):
> - Las dependencias resolvieron así: firebase_core 4.15, firebase_auth 6.7, cloud_firestore 6.10, firebase_ai 4.0, firebase_app_check 0.4.8, fl_chart 1.2, speech_to_text 7.5, image_picker 1.2.3, quick_actions 1.1.1 y google_fonts 8.2.1.
> - Todos los bloques de código Dart de este plan, más las Tareas 2.2 y 2.3, dan **0 errores y 0 warnings** en `flutter analyze`.
> - La subida de Auth/Firestore no rompió el código existente.
> - Los 11 tests del parser pasan.
> - **No validado:** el build de Gradle y el comportamiento en dispositivo. Eso lo verifica el ejecutor.

---

## 0. Contexto verificado del proyecto

- App Flutter `financial_control` ("Chiroless"). Firebase Auth + Firestore. Toolchain local: **Flutter 3.44.4 / Dart 3.12.2**.
- Estructura: `lib/features/<feature>/data/*_service.dart` (servicios), `lib/features/<feature>/presentation/pages|widgets/*.dart` (UI), modelos en `lib/models/`, compartidos en `lib/core/` y `lib/shared/widgets/`.
- Navegación imperativa (`Navigator.push` + `MaterialPageRoute`). No hay rutas con nombre.
- `HomePage` (`lib/features/home/presentation/pages/home_page.dart`) usa un `IndexedStack` con 5 hijos: `_buildHomeContent()`, `const StatisticsPage()`, `Container()`, `const AchievementsPage()` y `_buildProfileContent()`. El índice 2 es el botón "+" de la `BottomNavigationBar`, que llama a `_showAddTransactionOptions()`. Ese método abre `QuickAddSheet` (`lib/features/transactions/presentation/widgets/quick_add_sheet.dart`).
- Modelos (no cambian en este plan):
  - `Expense(id, userId, amount, category, date, month?, description, isImpulsive)`.
  - `Income(id, userId, amount, source, date, month?, description?)`.
  - `month` se calcula solo a partir de `date` (`"YYYY-MM"`).
- `TransactionService` (`lib/features/transactions/data/transaction_service.dart`):
  - `createExpense(Expense)`, `createIncome(Income)`.
  - `getUserExpenses(userId, {String? month})` y `getUserIncomes(userId, {String? month})`: sin `month` devuelven **solo el mes actual**.
  - `getMonthSummary(userId, {month})`: devuelve las claves `totalExpenses`, `totalIncomes`, `expensesByCategory`, entre otras.
- `BudgetService.getBudgetStatus(userId)` devuelve `{'hasBudget': true, 'totalLimit', 'totalSpent', 'percentageUsed', ...}` o `{'hasBudget': false}`.
- Categorías reales en uso:
  - Gasto: `Alimentación, Transporte, Entretenimiento, Salud, Educación, Vivienda, Ropa, Servicios, Otros`.
  - Ingreso: `Salario, Freelance, Negocio, Inversiones, Regalo, Beca, Padres, Otros`.
  - Hoy están duplicadas en `add_expense_page.dart`, `add_income_page.dart` y `quick_add_sheet.dart`.
  - Las listas `AppConstants.expenseCategories` e `AppConstants.incomeSources` tienen otros valores y **no se usan en ningún lado**.
- IA:
  - `lib/features/ai_assistant/data/gemini_service.dart` usa `google_generative_ai` (**paquete deprecado**) con la API key leída de `.env`.
  - `.env` está declarado como asset en `pubspec.yaml`, así que la key quedaría dentro del APK.
  - Hoy `.env` no tiene ninguna key, así que `AIAssistantPage` lanza una excepción al abrirse.
  - `GeminiService` solo se usa en `lib/features/ai_assistant/presentation/pages/ai_assistant_page.dart`.
- `firebase_storage` está en `pubspec.yaml` pero **no se usa** en `lib/`.
- Gráficas: `fl_chart: ^0.66.0`, solo en `lib/features/analytics/presentation/pages/statistics_page.dart`. Esa página usa la API vieja (`tooltipBgColor`, `SideTitleWidget(axisSide: ...)`).
- Android:
  - minSdk 24, compileSdk/targetSdk 36.
  - Kotlin plugin 2.1.0, AGP 8.9.1.
  - El release se firma con la clave debug.
  - `android/app/src/main/AndroidManifest.xml` ya tiene un bloque `<queries>` con `PROCESS_TEXT`.
- iOS: **no está configurado para Firebase** (no hay `GoogleService-Info.plist` ni `Podfile`). **Este plan solo verifica Android.** En iOS solo se agregan textos de permisos a `Info.plist`.
- Estado base: `flutter analyze` da 0 errores, 0 warnings y 141 infos. `flutter test` pasa (1 test).

### Reglas para el agente ejecutor

1. Ejecuta las fases **en orden**: 0 → 1 → 2 → … → 9. No adelantes trabajo de fases futuras.
2. Al terminar cada fase:
   - `flutter analyze` → **0 errores y 0 warnings**. Los `info` se toleran, pero no agregues nuevos `deprecated_member_use`.
   - `flutter test` → todo pasa.
   - Desde la Fase 2: `flutter build apk --debug` → compila.
3. Un commit por fase con el mensaje indicado (Conventional Commits), en la rama `feat/registro-inteligente`. **No hagas push** ni abras PR: eso lo decide el usuario.
4. No renombres archivos, clases ni métodos existentes salvo que la tarea lo pida.
5. Los bloques de código de este plan son la especificación. Cópialos tal cual; solo ajusta imports si el analizador lo exige, sin cambiar la lógica.
6. `print` para errores está permitido (es el patrón del proyecto).
7. **Pasos marcados 🧑 HUMANO:** detente, muestra al usuario la lista de pasos y espera su confirmación. No los simules.
8. **No uses `const`** delante de objetos de `fl_chart` (`SideTitles`, `AxisTitles`, `FlTitlesData`, etc.). Algunos no son const y fallaría la compilación.

---

## Decisiones abiertas (preguntar al usuario ANTES de la Fase 2)

- **D1 — Distribución de la app.** Firebase AI Logic exige App Check desde julio de 2026. En builds release, App Check usa **Play Integrity**, que solo funciona si la app se instala desde Google Play (o se prueba por los tracks de Play Console).
  - Pregunta: *"¿La app se distribuye por Google Play? Si se reparte como APK directo, las funciones de IA (texto/foto) fallarán en release."*
  - Si la respuesta es "no", **detente** y reporta. No desactives App Check ni metas tokens debug en release.
- **D2 — Commit del trabajo previo.** Hay trabajo sin commitear de `PLAN_MEJORAS.md` (Fases 1–3 completas).
  - Pregunta si se puede commitear como se describe en la Fase 0.

---

## FASE 0 — Cerrar el plan anterior y preparar la rama

### Tarea 0.1 — Terminar la tarea 3.8 pendiente de `PLAN_MEJORAS.md`

**Archivo:** `lib/features/achievements/presentation/pages/achievements_page.dart`

1. Busca la línea `if (_achievements.isEmpty) ...[` (cerca de la línea 327).
2. Cambia la condición por `if (unlockedAchievements.isEmpty && lockedAchievements.isEmpty) ...[`.
3. Usa los nombres reales de las dos listas locales que el archivo ya construye a partir de `AchievementTemplates.templates` (cerca de las líneas 85–98). Si esas variables no están en el scope de esa línea, **detente y pregunta**.

### Tarea 0.2 — Rama y commit base

```bash
git checkout -b feat/registro-inteligente
flutter analyze   # 0 errores, 0 warnings
flutter test      # pasa
git add -A
git commit -m "feat: registro rápido, arranque instantáneo y gamificación correcta"
```

> Este commit incluye todo lo hecho por `PLAN_MEJORAS.md`, incluido el propio archivo del plan. Solo hazlo con la confirmación D2.

---

## FASE 1 — Base visual compartida: categorías, colores y tarjeta

**Objetivo:** cada categoría tiene **un** nombre, **un** ícono y **un** color, definidos en un único lugar. Ingreso y gasto tienen colores semánticos. Existe un widget de tarjeta reutilizable.

### Tarea 1.1 — Crear el catálogo de categorías

**Archivo NUEVO:** `lib/core/constants/transaction_categories.dart`

```dart
import 'package:flutter/material.dart';

/// Nombre, ícono y color de una categoría de gasto o fuente de ingreso.
class CategoryInfo {
  final String name;
  final IconData icon;
  final Color color;

  const CategoryInfo(this.name, this.icon, this.color);
}

/// Única fuente de verdad de categorías. Los nombres coinciden con los
/// guardados en Firestore: NO los cambies o se pierde el historial.
class TransactionCategories {
  TransactionCategories._();

  static const List<CategoryInfo> expense = [
    CategoryInfo('Alimentación', Icons.restaurant, Color(0xFFF97316)),
    CategoryInfo('Transporte', Icons.directions_bus, Color(0xFF3B82F6)),
    CategoryInfo('Entretenimiento', Icons.movie, Color(0xFFA855F7)),
    CategoryInfo('Salud', Icons.medical_services, Color(0xFFEF4444)),
    CategoryInfo('Educación', Icons.school, Color(0xFF14B8A6)),
    CategoryInfo('Vivienda', Icons.home, Color(0xFF6366F1)),
    CategoryInfo('Ropa', Icons.shopping_bag, Color(0xFFEC4899)),
    CategoryInfo('Servicios', Icons.build, Color(0xFFEAB308)),
    CategoryInfo('Otros', Icons.more_horiz, Color(0xFF9CA3AF)),
  ];

  static const List<CategoryInfo> income = [
    CategoryInfo('Salario', Icons.work, Color(0xFF16A34A)),
    CategoryInfo('Freelance', Icons.laptop, Color(0xFF0EA5E9)),
    CategoryInfo('Negocio', Icons.business, Color(0xFF6366F1)),
    CategoryInfo('Inversiones', Icons.trending_up, Color(0xFF14B8A6)),
    CategoryInfo('Regalo', Icons.card_giftcard, Color(0xFFEC4899)),
    CategoryInfo('Beca', Icons.school, Color(0xFFF59E0B)),
    CategoryInfo('Padres', Icons.family_restroom, Color(0xFFF97316)),
    CategoryInfo('Otros', Icons.more_horiz, Color(0xFF9CA3AF)),
  ];

  static List<String> get expenseNames => expense.map((c) => c.name).toList();

  static List<String> get incomeNames => income.map((c) => c.name).toList();

  /// Devuelve la info de una categoría de gasto; si no existe, la de "Otros".
  static CategoryInfo expenseInfo(String name) =>
      expense.firstWhere((c) => c.name == name, orElse: () => expense.last);

  /// Devuelve la info de una fuente de ingreso; si no existe, la de "Otros".
  static CategoryInfo incomeInfo(String name) =>
      income.firstWhere((c) => c.name == name, orElse: () => income.last);
}
```

### Tarea 1.2 — Usar el catálogo en las páginas completas

**Archivo:** `lib/features/transactions/presentation/pages/add_expense_page.dart`

1. Agrega el import `import '../../../../core/constants/transaction_categories.dart';`.
2. Reemplaza toda la declaración `final List<String> _categories = [ ... ];` (cerca de la L34) por:
   ```dart
   final List<String> _categories = TransactionCategories.expenseNames;
   ```
3. **Borra** completa la declaración `final Map<String, IconData> _categoryIcons = { ... };` (cerca de la L46).
4. Reemplaza la expresión `_categoryIcons[category] ?? Icons.category` (cerca de la L276) por `TransactionCategories.expenseInfo(category).icon`.

**Archivo:** `lib/features/transactions/presentation/pages/add_income_page.dart`

1. Agrega el mismo import.
2. Reemplaza `final List<String> _sources = [ ... ];` (cerca de la L29) por:
   ```dart
   final List<String> _sources = TransactionCategories.incomeNames;
   ```
3. **Borra** `final Map<String, IconData> _sourceIcons = { ... };` (cerca de la L40).
4. Reemplaza `_sourceIcons[source] ?? Icons.attach_money` (cerca de la L239) por `TransactionCategories.incomeInfo(source).icon`.

> `quick_add_sheet.dart` NO se toca en esta fase: se reescribe completo en la Fase 5.

### Tarea 1.3 — Borrar las listas muertas de `AppConstants`

**Archivo:** `lib/core/constants/app_constants.dart`

1. Antes de borrar, comprueba que no se usan:
   ```bash
   grep -rn "AppConstants.expenseCategories\|AppConstants.incomeSources" lib
   ```
   Debe salir vacío. Si no sale vacío, **detente y pregunta**.
2. Borra el bloque `// Categorías de gastos` con su lista `expenseCategories`.
3. Borra el bloque `// Fuentes de ingresos` con su lista `incomeSources`.
4. Al final de la clase, agrega:
   ```dart
   // Modelo de Gemini usado vía Firebase AI Logic (ver Fase 2).
   // Si Firebase responde "model not found", consulta
   // https://firebase.google.com/docs/ai-logic/models y usa el modelo "flash" vigente.
   static const String geminiModel = 'gemini-3.8-flash';
   ```

### Tarea 1.4 — Colores semánticos en el tema

**Archivo:** `lib/core/theme/app_theme.dart`

Debajo de `static const Color accentColor = ...;`, agrega:

```dart
  static const Color incomeColor = Color(0xFF10B981); // Verde esmeralda
  static const Color expenseColor = Color(0xFFF43F5E); // Rosa/rojo suave
  static const Color borderColor = Color(0xFFEEF0F4);
```

### Tarea 1.5 — Widget de tarjeta compartido

**Archivo NUEVO:** `lib/shared/widgets/app_card.dart`

```dart
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Tarjeta blanca estándar de la app (borde sutil + sombra suave).
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}
```

### Tarea 1.6 — Colores de ingreso/gasto y ícono de categoría en home y estadísticas

**Archivo:** `lib/features/home/presentation/pages/home_page.dart`

1. Agrega el import `import '../../../../core/constants/transaction_categories.dart';`.
2. Hay dos llamadas a `_buildBalanceItem(` (cerca de las L425 y L434):
   - En la de `'Ingresos'`, cambia `AppTheme.secondaryColor` por `AppTheme.incomeColor`.
   - En la de `'Gastos'`, cambia `AppTheme.accentColor` por `AppTheme.expenseColor`.
3. Dentro de `Widget _buildTransactionItem(dynamic transaction)`:
   - Reemplaza estas líneas:
     ```dart
     final Color color = isExpense
         ? AppTheme.accentColor
         : AppTheme.secondaryColor;
     final IconData icon = isExpense ? Icons.arrow_upward : Icons.arrow_downward;
     ```
     por:
     ```dart
     final Color color = isExpense ? AppTheme.expenseColor : AppTheme.incomeColor;
     final CategoryInfo info = isExpense
         ? TransactionCategories.expenseInfo(title)
         : TransactionCategories.incomeInfo(title);
     ```
   - En el primer `Container` del `Row` (el del ícono), cambia `color: color.withOpacity(0.1),` por `color: info.color.withValues(alpha: 0.12),`.
   - En ese mismo `Container`, cambia `child: Icon(icon, color: color, size: 20),` por `child: Icon(info.icon, color: info.color, size: 20),`.
   - El texto del monto sigue usando `color`. No lo cambies.

**Archivo:** `lib/features/analytics/presentation/pages/statistics_page.dart`

En las dos llamadas a `_buildBalanceItem(` (cerca de las L161 y L170):
- En la de `'Ingresos'`, cambia `AppTheme.secondaryColor` por `AppTheme.incomeColor`.
- En la de `'Gastos'`, cambia `AppTheme.accentColor` por `AppTheme.expenseColor`.

### Criterios de aceptación Fase 1

- [ ] `grep -rn "'Alimentación'" lib` solo aparece en `transaction_categories.dart` y en `quick_add_sheet.dart` (este último se arregla en la Fase 5).
- [ ] La lista de "Movimientos recientes" del home muestra el ícono de la categoría con su color.
- [ ] `flutter analyze` sin errores ni warnings; `flutter test` pasa.

**Commit:** `refactor: catálogo único de categorías, colores semánticos y AppCard`

---

## FASE 2 — Migrar la IA a Firebase AI Logic + App Check (seguridad)

**Objetivo:** la app deja de llevar una API key de Gemini y usa Firebase AI Logic protegido con App Check. Es requisito para las Fases 4 y 5.

> Requiere respuesta a **D1**.

### Tarea 2.1 — Actualizar dependencias

1. Comprueba que `firebase_storage` no se usa:
   ```bash
   grep -rn "firebase_storage\|FirebaseStorage" lib
   ```
   Debe salir vacío. Si no sale vacío, NO lo quites en el paso 2.
2. Ejecuta en este orden:
   ```bash
   flutter pub remove google_generative_ai firebase_storage
   flutter pub upgrade --major-versions firebase_core firebase_auth cloud_firestore
   flutter pub add firebase_ai firebase_app_check
   ```
3. Verifica `pubspec.yaml`:
   - `firebase_core` debe quedar en `^4.x`, `firebase_auth` en `^6.x` y `cloud_firestore` en `^6.x`.
   - Deben aparecer `firebase_ai` (4.x) y `firebase_app_check`.
   - El motivo: `firebase_ai 4.0.0` exige `firebase_core ^4.14.0` y `firebase_auth ^6.6.0`, según su pubspec en pub.dev.
4. Si `pub` no resuelve versiones, **detente** y muestra el error al usuario. No fijes versiones a mano.

### Tarea 2.2 — Activar App Check

**Archivo:** `lib/main.dart`

1. Agrega estos imports:
   ```dart
   import 'package:firebase_app_check/firebase_app_check.dart';
   import 'package:flutter/foundation.dart';
   ```
2. Justo **después** del bloque `try { await Firebase.initializeApp(...) } on FirebaseException catch (e) { ... }` y **antes** de `runApp(const MyApp());`, agrega:
   ```dart
   await FirebaseAppCheck.instance.activate(
     providerAndroid: kDebugMode
         ? AndroidDebugProvider()
         : AndroidPlayIntegrityProvider(),
     providerApple: AppleAppAttestProvider(),
   );
   ```

API verificada en la firma de `activate()` de `firebase_app_check`: los parámetros `androidProvider`/`appleProvider` están **deprecados**; se usan `providerAndroid` y `providerApple`. Si el analizador dice que `AppleAppAttestProvider` no existe, quita la línea `providerApple` (iOS está fuera de alcance) y anota esa desviación en el commit.

### Tarea 2.3 — Migrar `GeminiService`

**Archivo:** `lib/features/ai_assistant/data/gemini_service.dart`

1. Reemplaza las dos primeras líneas de imports por:
   ```dart
   import 'package:firebase_ai/firebase_ai.dart';
   import '../../../core/constants/app_constants.dart';
   ```
2. Reemplaza el constructor completo por:
   ```dart
   GeminiService() {
     _model = FirebaseAI.googleAI().generativeModel(
       model: AppConstants.geminiModel,
     );
   }
   ```
3. No toques nada más del archivo. `Content.text(...)`, `generateContent(...)` y `response.text` existen igual en `firebase_ai`.

**Archivo:** `lib/core/config/env_config.dart`

Borra completo el getter `static String get geminiApiKey { ... }` y su comentario. El resto queda igual: `ADMIN_EMAIL` y `CONTACT_EMAIL` siguen leyéndose de `.env`.

Comprueba que no quedan referencias:

```bash
grep -rn "geminiApiKey\|google_generative_ai" lib
```

Debe salir vacío.

### Tarea 2.4 — Compilar

```bash
flutter analyze
flutter build apk --debug
```

Qué hacer si falla:
- **Si `flutter analyze` falla en código de Auth/Firestore** por la subida de versión mayor:
  - Arréglalo siguiendo **solo** las notas oficiales: https://firebase.google.com/support/release-notes/flutter.
  - No inventes reemplazos.
  - Si una corrección no aparece documentada, detente y pregunta.
- **Si el build de Gradle falla pidiendo una versión mayor de Kotlin** (mensaje tipo "Module was compiled with an incompatible version of Kotlin… expected version is X"):
  - En `android/settings.gradle.kts`, cambia `id("org.jetbrains.kotlin.android") version "2.1.0"` por la versión que pida el error.
  - Vuelve a compilar.
  - Cualquier otro error de Gradle: detente y muéstralo.

### Tarea 2.5 — 🧑 HUMANO: configurar Firebase Console

Muestra esta lista al usuario y espera a que confirme que la completó:

1. **AI Logic:** Firebase Console → *AI Services* → *AI Logic* → *Get started* → elegir **Gemini Developer API** → completar el asistente.
2. **Huellas SHA-256:**
   - Ejecutar `cd android && ./gradlew signingReport`.
   - Copiar el SHA-256 de la variante `debug`. Es la misma clave con la que hoy se firma el release.
   - En Firebase Console → *Configuración del proyecto* → app Android → *Agregar huella digital*.
3. **App Check:** Firebase Console → *Security* → *App Check* → *Apps* → registrar la app Android con **Play Integrity**.
4. **Token debug:**
   - Ejecutar la app en modo debug: `flutter run`.
   - En otra terminal, ejecutar `adb logcat | grep DebugAppCheckProvider`.
   - Copiar el UUID del mensaje *"Enter this debug secret into the allow list…"*.
   - En App Check → menú ⋮ de la app → *Manage debug tokens* → pegarlo.
   - **Nunca commitear ese token.**
5. **No** activar enforcement de App Check para Firestore ni Auth en este plan. AI Logic ya lo aplica por defecto.

### Criterios de aceptación Fase 2

- [ ] `grep -rn "GEMINI_API_KEY\|google_generative_ai" lib pubspec.yaml` sale vacío.
- [ ] En el dispositivo (debug), "Asistente IA" abre sin excepción y responde a un mensaje de chat.
- [ ] `flutter build apk --debug` compila.

**Commit:** `feat(ai): migrar Gemini a Firebase AI Logic con App Check`

---

## FASE 3 — Parser local de texto libre (sin red, con tests)

**Objetivo:** convertir frases como `"12.50 almuerzo ayer"` en un borrador de transacción, al instante y sin internet.

**Modo TDD:** activado para esta fase. Primero los tests en ROJO, luego la implementación en VERDE. Runner: `flutter test`.

### Tarea 3.1 — Modelo de borrador

**Archivo NUEVO:** `lib/features/transactions/data/transaction_draft.dart`

```dart
/// Borrador de transacción interpretado desde texto, voz o imagen.
/// El usuario SIEMPRE lo confirma en el QuickAddSheet antes de guardarlo.
class TransactionDraft {
  final bool isExpense;
  final double? amount;
  final String? category;
  final String description;
  final DateTime date;

  const TransactionDraft({
    required this.isExpense,
    this.amount,
    this.category,
    this.description = '',
    required this.date,
  });

  bool get isComplete => amount != null && amount! > 0 && category != null;
}
```

### Tarea 3.2 — Tests (escribir PRIMERO y verlos fallar)

**Archivo NUEVO:** `test/local_transaction_parser_test.dart`

```dart
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

  test('ingreso por verbo y categoría', () {
    final d = LocalTransactionParser.parse('recibí 450 sueldo', now: now);
    expect(d.isExpense, isFalse);
    expect(d.amount, 450.0);
    expect(d.category, 'Salario');
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
```

Ejecuta `flutter test test/local_transaction_parser_test.dart`. **Debe fallar** porque el archivo del parser aún no existe. Esa es la evidencia ROJA; anótala en el commit.

### Tarea 3.3 — Implementación

**Archivo NUEVO:** `lib/features/transactions/data/local_transaction_parser.dart`

```dart
import 'transaction_draft.dart';

/// Interpreta frases cortas ("12.50 almuerzo ayer") sin red ni IA.
/// ponytail: diccionario fijo de palabras clave y el primer número es el monto;
/// si no alcanza, el QuickAddSheet recurre a Gemini (Fase 4).
class LocalTransactionParser {
  LocalTransactionParser._();

  // Grupo 1: parte entera (con separadores de miles opcionales).
  // Grupo 2: 1-2 decimales tras punto o coma.
  static final RegExp _amountPattern = RegExp(
    r'(\d{1,3}(?:[.,]\d{3})+|\d+)(?:[.,](\d{1,2}))?(?!\d)',
  );
  static final RegExp _wordSplit = RegExp(r'[^a-záéíóúñü]+');

  static const Set<String> _dateWords = {'hoy', 'ayer', 'anteayer'};

  static const Set<String> _incomeTriggers = {
    'recibí', 'recibi', 'cobré', 'cobre', 'ingreso', 'ingresó',
    'pagaron', 'depositaron', 'transfirieron', 'gané', 'gane',
  };

  static const Set<String> _expenseTriggers = {
    'compré', 'compre', 'pagué', 'pague', 'gasté', 'gaste',
  };

  static const Map<String, List<String>> _expenseKeywords = {
    'Alimentación': [
      'almuerzo', 'desayuno', 'cena', 'comida', 'café', 'cafe',
      'restaurante', 'mercado', 'supermercado', 'súper', 'super', 'pizza',
      'hamburguesa', 'snack', 'pan', 'frutas', 'víveres', 'viveres', 'helado',
    ],
    'Transporte': [
      'uber', 'taxi', 'bus', 'pasaje', 'pasajes', 'gasolina', 'combustible',
      'metro', 'didi', 'indrive', 'indriver', 'parqueadero', 'peaje', 'cabify',
    ],
    'Entretenimiento': [
      'cine', 'netflix', 'spotify', 'juego', 'juegos', 'fiesta', 'concierto',
      'bar', 'discoteca', 'disney', 'salida',
    ],
    'Salud': [
      'farmacia', 'medicina', 'medicinas', 'doctor', 'médico', 'medico',
      'consulta', 'pastillas', 'hospital', 'dentista', 'odontólogo',
    ],
    'Educación': [
      'libro', 'libros', 'curso', 'universidad', 'matrícula', 'matricula',
      'colegio', 'copias', 'útiles', 'utiles', 'pensión', 'pension',
    ],
    'Vivienda': ['arriendo', 'alquiler', 'renta', 'hipoteca'],
    'Ropa': [
      'ropa', 'zapatos', 'camisa', 'camiseta', 'pantalón', 'pantalon',
      'zapatillas', 'vestido', 'chompa',
    ],
    'Servicios': [
      'luz', 'agua', 'internet', 'teléfono', 'telefono', 'celular', 'recarga',
      'gas', 'plan',
    ],
  };

  static const Map<String, List<String>> _incomeKeywords = {
    'Salario': ['salario', 'sueldo', 'quincena', 'nómina', 'nomina'],
    'Freelance': ['freelance', 'proyecto', 'cliente'],
    'Negocio': ['venta', 'ventas', 'vendí', 'vendi', 'negocio'],
    'Inversiones': ['intereses', 'dividendos', 'inversión', 'inversion'],
    'Regalo': ['regalo', 'regalaron'],
    'Beca': ['beca'],
    'Padres': ['papá', 'mamá', 'papi', 'mami', 'padres', 'mesada'],
  };

  static Set<String> _tokens(String text) => text
      .toLowerCase()
      .split(_wordSplit)
      .where((w) => w.isNotEmpty)
      .toSet();

  /// true si el texto tiene alguna palabra (no solo números/símbolos).
  static bool hasWords(String text) => _tokens(text).isNotEmpty;

  static TransactionDraft parse(String text, {DateTime? now}) {
    final current = now ?? DateTime.now();
    final tokens = _tokens(text);

    final forcedExpense = tokens.any(_expenseTriggers.contains);
    final isIncome = !forcedExpense &&
        (tokens.any(_incomeTriggers.contains) ||
            _findCategory(tokens, _incomeKeywords) != null);
    final category = _findCategory(
      tokens,
      isIncome ? _incomeKeywords : _expenseKeywords,
    );

    final match = _amountPattern.firstMatch(text);
    double? amount;
    if (match != null) {
      final whole = match.group(1)!.replaceAll(RegExp(r'[.,]'), '');
      final decimals = match.group(2);
      amount = double.parse(decimals == null ? whole : '$whole.$decimals');
    }

    var daysAgo = 0;
    if (tokens.contains('anteayer')) {
      daysAgo = 2;
    } else if (tokens.contains('ayer')) {
      daysAgo = 1;
    }
    final date = daysAgo == 0
        ? current
        : DateTime(
            current.year,
            current.month,
            current.day - daysAgo,
            current.hour,
            current.minute,
          );

    var rest = text;
    if (match != null) rest = rest.replaceFirst(match.group(0)!, ' ');
    final description = rest
        .replaceAll('\$', ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty && !_dateWords.contains(w.toLowerCase()))
        .join(' ');

    return TransactionDraft(
      isExpense: !isIncome,
      amount: amount,
      category: category,
      description: description,
      date: date,
    );
  }

  static String? _findCategory(
    Set<String> tokens,
    Map<String, List<String>> keywords,
  ) {
    for (final entry in keywords.entries) {
      if (entry.value.any(tokens.contains)) return entry.key;
    }
    return null;
  }
}
```

> ⚠️ Un `Set` const con elementos repetidos **no compila**. No agregues palabras repetidas a `_incomeTriggers`, `_expenseTriggers` ni `_dateWords`.

Ejecuta `flutter test`. **Todos los tests deben pasar (VERDE).** Si alguno falla, corrige el parser, **no** el test. Si crees que el test está mal, detente y pregunta.

### Criterios de aceptación Fase 3

- [ ] Los 11 tests de `test/local_transaction_parser_test.dart` pasan.
- [ ] `flutter analyze` sin errores ni warnings.

**Commit:** `feat(transactions): parser local de texto libre con tests`

---

## FASE 4 — Extracción con IA desde texto o foto de comprobante

**Objetivo:** cuando el parser local no basta, o cuando el usuario sube una captura de transferencia, Gemini devuelve un JSON estructurado y validado.

### Tarea 4.1 — Servicio de extracción

**Archivo NUEVO:** `lib/features/transactions/data/transaction_extraction_service.dart`

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_ai/firebase_ai.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/transaction_categories.dart';
import 'transaction_draft.dart';

/// Extrae una transacción desde texto libre o una imagen usando Gemini
/// (Firebase AI Logic). Nunca lanza: devuelve null si algo falla.
class TransactionExtractionService {
  TransactionExtractionService()
    : _model = FirebaseAI.googleAI().generativeModel(
        model: AppConstants.geminiModel,
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
          responseSchema: _schema,
        ),
      );

  final GenerativeModel _model;

  static List<String> get _allCategories => {
    ...TransactionCategories.expenseNames,
    ...TransactionCategories.incomeNames,
  }.toList();

  static final Schema _schema = Schema.object(
    properties: {
      'isExpense': Schema.boolean(),
      'amount': Schema.number(),
      'category': Schema.enumString(enumValues: _allCategories),
      'description': Schema.string(),
      'date': Schema.string(),
    },
    optionalProperties: ['amount', 'description', 'date'],
  );

  Future<TransactionDraft?> fromText(String text) {
    final prompt = '${_instructions()}\nTexto del usuario: """$text"""';
    return _run([Content.text(prompt)]);
  }

  Future<TransactionDraft?> fromImage(Uint8List bytes, String mimeType) {
    final prompt =
        '${_instructions()}\n'
        'La imagen es una captura de un comprobante de transferencia, pago, '
        'depósito o recibo. Si el usuario envió o pagó dinero, isExpense es '
        'true; si lo recibió, isExpense es false. Si no se puede saber, usa '
        'isExpense = true. En description NO incluyas números de cuenta, '
        'cédulas ni nombres completos: como máximo el primer nombre de la otra '
        'persona o el nombre del comercio.';
    return _run([
      Content.multi([TextPart(prompt), InlineDataPart(mimeType, bytes)]),
    ]);
  }

  String _instructions() {
    final now = DateTime.now();
    final today =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    return 'Eres un extractor de transacciones de finanzas personales. '
        'Hoy es $today.\n'
        'Devuelve: isExpense (true = gasto o pago, false = dinero recibido), '
        'amount (número positivo, sin símbolo de moneda, punto decimal), '
        'category (elige SOLO de la lista que corresponda al tipo; si dudas '
        'usa "Otros"), description (máximo 6 palabras, en español), '
        'date (formato YYYY-MM-DD; si no se menciona, usa $today).\n'
        'Categorías de gasto: ${TransactionCategories.expenseNames.join(', ')}.\n'
        'Categorías de ingreso: ${TransactionCategories.incomeNames.join(', ')}.';
  }

  Future<TransactionDraft?> _run(List<Content> content) async {
    try {
      final response = await _model.generateContent(content);
      final text = response.text;
      if (text == null) return null;
      final map = jsonDecode(text) as Map<String, dynamic>;
      return _toDraft(map);
    } catch (e) {
      print('Error extrayendo transacción: $e');
      return null;
    }
  }

  TransactionDraft _toDraft(Map<String, dynamic> map) {
    final isExpense = map['isExpense'] != false;
    final rawAmount = map['amount'];
    final amount = rawAmount is num && rawAmount > 0
        ? rawAmount.toDouble()
        : null;
    final valid = isExpense
        ? TransactionCategories.expenseNames
        : TransactionCategories.incomeNames;
    final rawCategory = map['category'];
    final category = rawCategory is String && valid.contains(rawCategory)
        ? rawCategory
        : 'Otros';
    final rawDescription = map['description'];
    return TransactionDraft(
      isExpense: isExpense,
      amount: amount,
      category: category,
      description: rawDescription is String ? rawDescription.trim() : '',
      date: _parseDate(map['date']),
    );
  }

  /// Fecha futura o inválida → ahora. Hoy → ahora (con hora real).
  /// Otro día → ese día a las 12:00.
  DateTime _parseDate(Object? raw) {
    final now = DateTime.now();
    final parsed = raw is String ? DateTime.tryParse(raw) : null;
    if (parsed == null || parsed.isAfter(now)) return now;
    if (parsed.year == now.year &&
        parsed.month == now.month &&
        parsed.day == now.day) {
      return now;
    }
    return DateTime(parsed.year, parsed.month, parsed.day, 12);
  }
}
```

**Fuentes de la API usada** (consúltalas si el analizador marca algún nombre como inexistente; no inventes alternativas):
- Salida estructurada (`Schema.object`, `Schema.enumString`, `optionalProperties`, `GenerationConfig(responseMimeType, responseSchema)`): https://firebase.google.com/docs/ai-logic/generate-structured-output?platform=flutter
- Imágenes (`Content.multi`, `TextPart`, `InlineDataPart(mimeType, bytes)`; formatos png/jpeg/webp; límite de 20 MB por request): https://firebase.google.com/docs/ai-logic/analyze-images?platform=flutter

### Criterios de aceptación Fase 4

- [ ] `flutter analyze` sin errores ni warnings.
- [ ] La prueba manual se hace en la Fase 5, cuando haya UI.

**Commit:** `feat(transactions): extracción de transacciones con Gemini (texto e imagen)`

---

## FASE 5 — QuickAddSheet inteligente: texto, voz y foto

**Objetivo:** en el mismo sheet del "+", el usuario puede:
- escribir o dictar `"12.50 almuerzo ayer"`, o
- subir la captura de una transferencia.

En ambos casos los campos se rellenan solos y el usuario confirma con **Guardar**. Nada se guarda sin confirmación.

### Tarea 5.1 — Dependencias

```bash
flutter pub add speech_to_text image_picker
```

Versiones verificadas en pub.dev: `speech_to_text` 7.5.0 e `image_picker` 1.2.3.

### Tarea 5.2 — Permisos Android

**Archivo:** `android/app/src/main/AndroidManifest.xml`

1. Debajo de `<uses-permission android:name="android.permission.USE_EXACT_ALARM"/>`, agrega:
   ```xml
   <uses-permission android:name="android.permission.RECORD_AUDIO"/>
   ```
2. Dentro del bloque `<queries>` que ya existe al final, después del `<intent>` de `PROCESS_TEXT`, agrega:
   ```xml
   <intent>
       <action android:name="android.speech.RecognitionService" />
   </intent>
   ```

`image_picker` no necesita cambios en el manifest (lo confirma su README).

### Tarea 5.3 — Textos de permisos iOS (solo texto; iOS no se compila en este plan)

**Archivo:** `ios/Runner/Info.plist`. Dentro del `<dict>` principal, antes del `</dict>` final, agrega:

```xml
<key>NSMicrophoneUsageDescription</key>
<string>Chiroless usa el micrófono para que dictes tus gastos e ingresos.</string>
<key>NSSpeechRecognitionUsageDescription</key>
<string>Chiroless convierte tu voz en texto para registrar transacciones.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Chiroless lee capturas de comprobantes para registrar transacciones.</string>
<key>NSCameraUsageDescription</key>
<string>Chiroless fotografía recibos para registrar transacciones.</string>
```

### Tarea 5.4 — Reescribir `QuickAddSheet`

**Archivo:** `lib/features/transactions/presentation/widgets/quick_add_sheet.dart`. **Reemplaza TODO el contenido** por:

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../../../core/constants/transaction_categories.dart';
import '../../../../core/services/firebase_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../models/expense_model.dart';
import '../../../../models/income_model.dart';
import '../../../achievements/data/gamification_service.dart';
import '../../data/local_transaction_parser.dart';
import '../../data/transaction_draft.dart';
import '../../data/transaction_extraction_service.dart';
import '../../data/transaction_service.dart';
import '../pages/add_expense_page.dart';
import '../pages/add_income_page.dart';

class QuickAddResult {
  final bool isExpense;
  final double amount;
  final DateTime date;

  QuickAddResult({
    required this.isExpense,
    required this.amount,
    required this.date,
  });
}

class QuickAddSheet extends StatefulWidget {
  final bool initialIsExpense;

  /// Categorías de gasto ordenadas por uso (más usada primero). Las que
  /// falten se agregan al final en el orden por defecto.
  final List<String> expenseCategoryOrder;

  const QuickAddSheet({
    super.key,
    this.initialIsExpense = true,
    this.expenseCategoryOrder = const [],
  });

  @override
  State<QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends State<QuickAddSheet> {
  final _amountController = TextEditingController();
  final _smartController = TextEditingController();
  final _transactionService = TransactionService();
  final _gamificationService = GamificationService();
  final _firebaseService = FirebaseService();
  final _extractionService = TransactionExtractionService();
  final _speech = SpeechToText();
  final _imagePicker = ImagePicker();

  late bool _isExpense;
  late String _selectedCategory;
  String _description = '';
  DateTime _date = DateTime.now();
  String? _error;
  String? _smartMessage;
  bool _isInterpreting = false;
  bool _isListening = false;

  List<String> get _expenseOptions {
    final defaults = TransactionCategories.expenseNames;
    final ordered = widget.expenseCategoryOrder
        .where(defaults.contains)
        .toList();
    return [...ordered, ...defaults.where((c) => !ordered.contains(c))];
  }

  List<String> get _options =>
      _isExpense ? _expenseOptions : TransactionCategories.incomeNames;

  Color get _modeColor =>
      _isExpense ? AppTheme.expenseColor : AppTheme.incomeColor;

  CategoryInfo _infoOf(String name) => _isExpense
      ? TransactionCategories.expenseInfo(name)
      : TransactionCategories.incomeInfo(name);

  bool get _isToday {
    final now = DateTime.now();
    return _date.year == now.year &&
        _date.month == now.month &&
        _date.day == now.day;
  }

  @override
  void initState() {
    super.initState();
    _isExpense = widget.initialIsExpense;
    _selectedCategory = _options.first;
  }

  @override
  void dispose() {
    _speech.cancel();
    _amountController.dispose();
    _smartController.dispose();
    super.dispose();
  }

  void _setMode(bool isExpense) {
    setState(() {
      _isExpense = isExpense;
      _selectedCategory = _options.first;
      _error = null;
    });
  }

  void _applyDraft(TransactionDraft draft, String message) {
    setState(() {
      _isExpense = draft.isExpense;
      final category = draft.category;
      _selectedCategory = category != null && _options.contains(category)
          ? category
          : _options.first;
      if (draft.amount != null) {
        _amountController.text = draft.amount!.toStringAsFixed(2);
      }
      _description = draft.description;
      _date = draft.date;
      _error = null;
      _smartMessage = message;
    });
  }

  Future<void> _interpretText(String text) async {
    final input = text.trim();
    if (input.isEmpty || _isInterpreting) return;

    final local = LocalTransactionParser.parse(input);
    if (local.isComplete || !LocalTransactionParser.hasWords(input)) {
      _applyDraft(local, 'Revisa los datos y toca Guardar');
      return;
    }

    setState(() {
      _isInterpreting = true;
      _smartMessage = 'Interpretando…';
    });
    final aiDraft = await _extractionService.fromText(input);
    if (!mounted) return;
    setState(() => _isInterpreting = false);
    _applyDraft(
      aiDraft ?? local,
      aiDraft == null
          ? 'No pude interpretarlo del todo. Completa los datos.'
          : 'Revisa los datos y toca Guardar',
    );
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _speech.stop();
      if (mounted) setState(() => _isListening = false);
      return;
    }
    final available = await _speech.initialize(
      onStatus: (status) {
        if ((status == 'done' || status == 'notListening') && mounted) {
          setState(() => _isListening = false);
        }
      },
    );
    if (!mounted) return;
    if (!available) {
      setState(() => _smartMessage = 'Reconocimiento de voz no disponible');
      return;
    }
    final locales = await _speech.locales();
    final spanish = locales.where((l) => l.localeId.startsWith('es')).toList();
    if (!mounted) return;
    setState(() {
      _isListening = true;
      _smartMessage = 'Escuchando… di por ejemplo "doce cincuenta almuerzo"';
    });
    await _speech.listen(
      localeId: spanish.isEmpty ? null : spanish.first.localeId,
      onResult: (result) {
        _smartController.text = result.recognizedWords;
        if (result.finalResult) {
          setState(() => _isListening = false);
          _interpretText(result.recognizedWords);
        }
      },
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    if (_isInterpreting) return;
    final XFile? image;
    try {
      image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1280,
        imageQuality: 70,
      );
    } catch (e) {
      setState(() => _smartMessage = 'No se pudo abrir la imagen');
      return;
    }
    if (image == null || !mounted) return;

    setState(() {
      _isInterpreting = true;
      _smartMessage = 'Leyendo comprobante…';
    });
    final bytes = await image.readAsBytes();
    final mimeType =
        image.mimeType ??
        (image.path.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg');
    final draft = await _extractionService.fromImage(bytes, mimeType);
    if (!mounted) return;
    setState(() => _isInterpreting = false);
    if (draft == null) {
      setState(
        () => _smartMessage =
            'No pude leer el comprobante. Ingresa los datos a mano.',
      );
      return;
    }
    _applyDraft(draft, 'Revisa los datos y toca Guardar');
  }

  void _save() {
    final amount = double.tryParse(_amountController.text.replaceAll(',', '.'));
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Monto inválido');
      return;
    }

    final user = _firebaseService.currentUser;
    if (user == null) return;

    HapticFeedback.lightImpact();

    if (_isExpense) {
      final expense = Expense(
        id: null,
        userId: user.uid,
        amount: amount,
        category: _selectedCategory,
        description: _description,
        date: _date,
        isImpulsive: false,
      );
      unawaited(_transactionService.createExpense(expense));
      unawaited(
        _gamificationService.onTransactionRegistered(user.uid, isExpense: true),
      );
    } else {
      final income = Income(
        id: null,
        userId: user.uid,
        amount: amount,
        source: _selectedCategory,
        description: _description,
        date: _date,
      );
      unawaited(_transactionService.createIncome(income));
      unawaited(
        _gamificationService.onTransactionRegistered(
          user.uid,
          isExpense: false,
        ),
      );
    }

    Navigator.pop(
      context,
      QuickAddResult(isExpense: _isExpense, amount: amount, date: _date),
    );
  }

  void _openFullPage() {
    final navigator = Navigator.of(context);
    navigator.pop();
    navigator.push(
      MaterialPageRoute(
        builder: (context) =>
            _isExpense ? const AddExpensePage() : const AddIncomePage(),
      ),
    );
  }

  Widget _buildSmartInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _smartController,
                textInputAction: TextInputAction.done,
                onSubmitted: _interpretText,
                decoration: InputDecoration(
                  hintText: 'Ej: 12.50 almuerzo ayer',
                  fillColor: AppTheme.backgroundColor,
                  prefixIcon: const Icon(Icons.auto_awesome),
                  suffixIcon: _isInterpreting
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : IconButton(
                          icon: const Icon(Icons.send),
                          onPressed: () =>
                              _interpretText(_smartController.text),
                        ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              tooltip: 'Dictar',
              onPressed: _isInterpreting ? null : _toggleListening,
              icon: Icon(
                _isListening ? Icons.stop_circle : Icons.mic,
                color: _isListening ? AppTheme.expenseColor : null,
              ),
            ),
            PopupMenuButton<ImageSource>(
              tooltip: 'Leer comprobante',
              enabled: !_isInterpreting,
              icon: const Icon(Icons.photo_camera_outlined),
              onSelected: _pickImage,
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: ImageSource.gallery,
                  child: Text('Captura de la galería'),
                ),
                PopupMenuItem(
                  value: ImageSource.camera,
                  child: Text('Tomar foto'),
                ),
              ],
            ),
          ],
        ),
        if (_smartMessage != null) ...[
          const SizedBox(height: 6),
          Text(
            _smartMessage!,
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _buildSmartInput(),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  children: [
                    ChoiceChip(
                      label: const Text('Gasto'),
                      selected: _isExpense,
                      selectedColor: AppTheme.expenseColor.withValues(
                        alpha: 0.14,
                      ),
                      labelStyle: TextStyle(
                        color: _isExpense
                            ? AppTheme.expenseColor
                            : Colors.grey.shade700,
                        fontWeight: FontWeight.w700,
                      ),
                      onSelected: (_) => _setMode(true),
                    ),
                    ChoiceChip(
                      label: const Text('Ingreso'),
                      selected: !_isExpense,
                      selectedColor: AppTheme.incomeColor.withValues(
                        alpha: 0.14,
                      ),
                      labelStyle: TextStyle(
                        color: !_isExpense
                            ? AppTheme.incomeColor
                            : Colors.grey.shade700,
                        fontWeight: FontWeight.w700,
                      ),
                      onSelected: (_) => _setMode(false),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _amountController,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: InputDecoration(
                    prefixText: '\$',
                    hintText: '0.00',
                    errorText: _error,
                    fillColor: AppTheme.backgroundColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 18,
                    ),
                  ),
                  onChanged: (_) {
                    if (_error != null) {
                      setState(() => _error = null);
                    }
                  },
                  onFieldSubmitted: (_) => _save(),
                ),
                if (!_isToday || _description.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (!_isToday)
                        InputChip(
                          avatar: const Icon(Icons.event, size: 18),
                          label: Text(DateFormat('d MMM', 'es').format(_date)),
                          onDeleted: () =>
                              setState(() => _date = DateTime.now()),
                        ),
                      if (_description.isNotEmpty)
                        InputChip(
                          avatar: const Icon(Icons.notes, size: 18),
                          label: Text(_description),
                          onDeleted: () => setState(() => _description = ''),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _options.map((option) {
                    final selected = option == _selectedCategory;
                    final info = _infoOf(option);
                    return ChoiceChip(
                      avatar: Icon(
                        info.icon,
                        size: 18,
                        color: selected ? info.color : AppTheme.textSecondary,
                      ),
                      label: Text(option),
                      selected: selected,
                      selectedColor: info.color.withValues(alpha: 0.14),
                      labelStyle: TextStyle(
                        color: selected ? info.color : Colors.grey.shade700,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                      onSelected: (_) {
                        setState(() => _selectedCategory = option);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isInterpreting ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _modeColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('Guardar'),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _openFullPage,
                  child: const Text('Más opciones'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

> Si el analizador dice que `localeId` u `onResult` no existen en `SpeechToText.listen`, revisa el README de https://pub.dev/packages/speech_to_text (versión instalada). En la 7.5.0 ambos parámetros están documentados. Ajusta solo lo que la documentación indique.

### Tarea 5.5 — Integrar el sheet en el home

**Archivo:** `lib/features/home/presentation/pages/home_page.dart`

1. Junto a los demás campos de estado (cerca de la L36–47), agrega:
   ```dart
   List<String> _topExpenseCategories = [];
   final ValueNotifier<int> _dataVersion = ValueNotifier<int>(0);
   ```
2. En `_loadTransactionData()`:
   - Justo después de la línea `combined.sort((a, b) => b.date.compareTo(a.date));`, agrega:
     ```dart
     final counts = <String, int>{};
     for (final e in expenses) {
       counts[e.category] = (counts[e.category] ?? 0) + 1;
     }
     final topCategories = counts.keys.toList()
       ..sort((a, b) => counts[b]!.compareTo(counts[a]!));
     ```
   - Dentro del `setState` que asigna `recentTransactions = ...`, agrega la línea `_topExpenseCategories = topCategories;`.
3. Reemplaza el método `_showAddTransactionOptions` completo por:
   ```dart
   void _showAddTransactionOptions({bool isExpense = true}) async {
     final result = await showModalBottomSheet<QuickAddResult>(
       context: context,
       isScrollControlled: true,
       backgroundColor: Colors.white,
       shape: const RoundedRectangleBorder(
         borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
       ),
       builder: (context) => QuickAddSheet(
         initialIsExpense: isExpense,
         expenseCategoryOrder: _topExpenseCategories,
       ),
     );
     if (result != null && mounted) {
       _applyOptimisticTransaction(result);
       _dataVersion.value++;
       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(
           content: Text(
             result.isExpense ? 'Gasto guardado' : 'Ingreso guardado',
           ),
           backgroundColor: AppTheme.incomeColor,
           duration: const Duration(seconds: 2),
         ),
       );
     }
   }
   ```
4. En `_applyOptimisticTransaction(QuickAddResult result)`, agrega como **primeras líneas** del método, antes del `setState`:
   ```dart
   final now = DateTime.now();
   if (result.date.year != now.year || result.date.month != now.month) return;
   ```
   Así un gasto de "ayer" del mes anterior no altera los totales del mes actual.
5. En `_navigateToAddExpense` y `_navigateToAddIncome`, dentro de `if (result == true) {`, agrega `_dataVersion.value++;` después de `_loadUser();`.
6. En `build`, dentro del `IndexedStack`, reemplaza `const StatisticsPage(),` por:
   ```dart
   StatisticsPage(refreshListenable: _dataVersion),
   ```
7. `HomePage` no tiene `dispose`. Agrega este método después de `initState`:
   ```dart
   @override
   void dispose() {
     _dataVersion.dispose();
     super.dispose();
   }
   ```

### Tarea 5.6 — Estadísticas que se recargan solas

**Archivo:** `lib/features/analytics/presentation/pages/statistics_page.dart`

1. Reemplaza:
   ```dart
   class StatisticsPage extends StatefulWidget {
     const StatisticsPage({Key? key}) : super(key: key);
   ```
   por:
   ```dart
   class StatisticsPage extends StatefulWidget {
     /// Cuando notifica, la página recarga sus datos.
     final Listenable? refreshListenable;

     const StatisticsPage({super.key, this.refreshListenable});
   ```
2. En `initState`, después de `_loadData();`, agrega:
   ```dart
   widget.refreshListenable?.addListener(_loadData);
   ```
3. Agrega (o completa, si ya existe) el `dispose` del `State`:
   ```dart
   @override
   void dispose() {
     widget.refreshListenable?.removeListener(_loadData);
     super.dispose();
   }
   ```

### Criterios de aceptación Fase 5 (en dispositivo Android, modo debug)

- [ ] Toca "+" → escribe `25 almuerzo` → Enter: el monto queda en 25.00, la categoría en Alimentación y aparece el chip "almuerzo". Toca Guardar → el balance del home baja 25.
- [ ] Escribe `pagué 8 por algo raro` → aparece "Interpretando…" → los campos se rellenan (vía Gemini).
- [ ] Toca 🎤 → dicta "diez dólares taxi" → se rellena con Transporte.
- [ ] Toca 📷 → "Captura de la galería" → elige la captura de una transferencia → se rellenan el monto, el tipo y la fecha.
- [ ] Sin internet, `25 almuerzo` sigue funcionando (parser local).
- [ ] Tras guardar, la pestaña Estadísticas muestra el dato nuevo sin hacer pull-to-refresh.
- [ ] `flutter analyze` sin errores ni warnings; `flutter test` pasa; `flutter build apk --debug` compila.

**Commit:** `feat(transactions): registro por texto, voz y foto en el QuickAddSheet`

---

## FASE 6 — Accesos directos del ícono (App Shortcuts)

**Objetivo:** al mantener presionado el ícono de la app aparecen "Nuevo gasto" y "Nuevo ingreso", que abren directo el `QuickAddSheet`.

### Tarea 6.1 — Dependencia

```bash
flutter pub add quick_actions
```

Versión verificada: 1.1.1. En Android funciona desde la API 25.

### Tarea 6.2 — Íconos Android

**Archivo NUEVO:** `android/app/src/main/res/drawable/ic_shortcut_expense.xml`

```xml
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="24dp"
    android:height="24dp"
    android:viewportWidth="24"
    android:viewportHeight="24">
    <path
        android:fillColor="#F43F5E"
        android:pathData="M4,12l1.41,1.41L11,7.83V20h2V7.83l5.58,5.59L20,12l-8,-8 -8,8z" />
</vector>
```

**Archivo NUEVO:** `android/app/src/main/res/drawable/ic_shortcut_income.xml`

```xml
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="24dp"
    android:height="24dp"
    android:viewportWidth="24"
    android:viewportHeight="24">
    <path
        android:fillColor="#10B981"
        android:pathData="M20,12l-1.41,-1.41L13,16.17V4h-2v12.17l-5.58,-5.59L4,12l8,8 8,-8z" />
</vector>
```

**Archivo NUEVO:** `android/app/src/main/res/raw/keep.xml`. Evita que el shrinker de release borre los íconos, que solo se referencian desde Dart (lo advierte el README de `quick_actions`):

```xml
<?xml version="1.0" encoding="utf-8"?>
<resources xmlns:tools="http://schemas.android.com/tools"
    tools:keep="@drawable/ic_shortcut_expense,@drawable/ic_shortcut_income" />
```

### Tarea 6.3 — Servicio de accesos directos

**Archivo NUEVO:** `lib/core/services/shortcut_service.dart`

```dart
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
```

### Tarea 6.4 — Inicializar en `main.dart`

**Archivo:** `lib/main.dart`

1. Agrega el import `import 'core/services/shortcut_service.dart';`.
2. Después de `unawaited(_initNotifications());`, agrega:
   ```dart
   unawaited(_initShortcuts());
   ```
3. Debajo de la función `_initNotifications`, agrega:
   ```dart
   Future<void> _initShortcuts() async {
     try {
       await ShortcutService.init();
     } catch (e) {
       print('Error inicializando accesos directos: $e');
     }
   }
   ```

### Tarea 6.5 — Consumir el atajo en `HomePage`

**Archivo:** `lib/features/home/presentation/pages/home_page.dart`

1. Agrega el import `import '../../../../core/services/shortcut_service.dart';`.
2. En `initState`, después de `_loadUser();`, agrega:
   ```dart
   ShortcutService.pending.addListener(_handleShortcut);
   WidgetsBinding.instance.addPostFrameCallback((_) => _handleShortcut());
   ```
3. En `dispose` (creado en la Tarea 5.5), agrega como primera línea:
   ```dart
   ShortcutService.pending.removeListener(_handleShortcut);
   ```
4. Agrega este método a la clase `State`:
   ```dart
   void _handleShortcut() {
     final type = ShortcutService.pending.value;
     if (type == null || !mounted) return;
     ShortcutService.pending.value = null;
     _showAddTransactionOptions(
       isExpense: type != ShortcutService.addIncome,
     );
   }
   ```

> Si el usuario no ha iniciado sesión, el splash lo manda a Login. El atajo queda guardado en `pending` y se abre cuando `HomePage` aparezca tras el login. Es el comportamiento esperado.

### Criterios de aceptación Fase 6 (dispositivo Android)

- [ ] Al mantener presionado el ícono aparecen "Nuevo gasto" y "Nuevo ingreso", con sus íconos.
- [ ] Con la app cerrada, "Nuevo ingreso" abre la app y el sheet aparece en modo Ingreso.
- [ ] Con la app en segundo plano, "Nuevo gasto" abre el sheet en modo Gasto.
- [ ] `flutter analyze` / `flutter test` / `flutter build apk --debug` OK.

**Commit:** `feat: accesos directos del ícono para registrar gasto o ingreso`

---

## FASE 7 — Gráficas claras

**Objetivo:** reemplazar el gráfico de 2 barras y el pie genérico por:
1. una dona con el total en el centro y colores fijos por categoría;
2. la tendencia de los últimos 6 meses (ingresos vs gastos);
3. el ritmo de gasto del mes contra el presupuesto.

### Tarea 7.1 — Actualizar `fl_chart`

```bash
flutter pub upgrade --major-versions fl_chart
```

Debe quedar en `^1.2.0` o superior. Cambios incompatibles verificados en el changelog:
- `tooltipBgColor` → `getTooltipColor: (group) => color`.
- `SideTitleWidget(axisSide: meta.axisSide, ...)` → `SideTitleWidget(meta: meta, ...)`.

Los dos usos viejos están en `_buildBarChart`, que esta fase borra.

### Tarea 7.2 — Totales por mes en `TransactionService`

**Archivo:** `lib/features/transactions/data/transaction_service.dart`

1. Al final del archivo, **fuera** de la clase `TransactionService`, agrega:
   ```dart
   /// Totales de un mes. [month] con formato "YYYY-MM".
   class MonthTotals {
     final String month;
     final double income;
     final double expense;

     const MonthTotals({
       required this.month,
       required this.income,
       required this.expense,
     });
   }
   ```
2. Dentro de la clase `TransactionService`, después de `getMonthSummary`, agrega:
   ```dart
   /// Totales de los últimos [months] meses (incluye el actual), del más
   /// antiguo al más reciente.
   /// ponytail: 2 consultas por mes; pasar a una consulta por rango de fechas
   /// si se piden muchos meses.
   Future<List<MonthTotals>> getLastMonthsTotals(
     String userId, {
     int months = 6,
   }) async {
     final now = DateTime.now();
     final keys = List.generate(months, (i) {
       final d = DateTime(now.year, now.month - (months - 1 - i));
       return '${d.year}-${d.month.toString().padLeft(2, '0')}';
     });
     return Future.wait(
       keys.map((key) async {
         final expensesFuture = getUserExpenses(userId, month: key);
         final incomes = await getUserIncomes(userId, month: key);
         final expenses = await expensesFuture;
         return MonthTotals(
           month: key,
           income: incomes.fold<double>(0, (s, i) => s + i.amount),
           expense: expenses.fold<double>(0, (s, e) => s + e.amount),
         );
       }),
     );
   }
   ```

### Tarea 7.3 — Widget: dona por categoría

**Archivo NUEVO:** `lib/features/analytics/presentation/widgets/category_donut_chart.dart`

```dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/transaction_categories.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_card.dart';

/// Dona de gastos por categoría con el total (o la categoría tocada) al centro.
class CategoryDonutChart extends StatefulWidget {
  final Map<String, double> expensesByCategory;

  const CategoryDonutChart({super.key, required this.expensesByCategory});

  @override
  State<CategoryDonutChart> createState() => _CategoryDonutChartState();
}

class _CategoryDonutChartState extends State<CategoryDonutChart> {
  int? _touchedIndex;

  /// Ordena de mayor a menor y junta en "Otros" lo que pese < 5 % del total.
  List<MapEntry<String, double>> _groupedEntries(double total) {
    final sorted =
        widget.expensesByCategory.entries.where((e) => e.value > 0).toList()
          ..sort((a, b) => b.value.compareTo(a.value));
    final result = <MapEntry<String, double>>[];
    double others = 0;
    for (final entry in sorted) {
      if (entry.key == 'Otros' || entry.value / total < 0.05) {
        others += entry.value;
      } else {
        result.add(entry);
      }
    }
    if (others > 0) result.add(MapEntry('Otros', others));
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.expensesByCategory.values.fold<double>(
      0,
      (s, v) => s + v,
    );
    if (total <= 0) return const SizedBox.shrink();

    final entries = _groupedEntries(total);
    final touched = _touchedIndex != null && _touchedIndex! < entries.length
        ? entries[_touchedIndex!]
        : null;

    return AppCard(
      margin: const EdgeInsets.only(bottom: 16),
      child: SizedBox(
        height: 220,
        child: Stack(
          alignment: Alignment.center,
          children: [
            PieChart(
              PieChartData(
                sectionsSpace: 3,
                centerSpaceRadius: 70,
                pieTouchData: PieTouchData(
                  touchCallback: (event, response) {
                    final section = response?.touchedSection;
                    if (!event.isInterestedForInteractions || section == null) {
                      setState(() => _touchedIndex = null);
                      return;
                    }
                    final index = section.touchedSectionIndex;
                    setState(() => _touchedIndex = index < 0 ? null : index);
                  },
                ),
                sections: [
                  for (var i = 0; i < entries.length; i++)
                    PieChartSectionData(
                      color: TransactionCategories.expenseInfo(
                        entries[i].key,
                      ).color,
                      value: entries[i].value,
                      showTitle: false,
                      radius: i == _touchedIndex ? 34 : 28,
                    ),
                ],
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  touched?.key ?? 'Total gastado',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '\$${(touched?.value ?? total).toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                if (touched != null)
                  Text(
                    '${(touched.value / total * 100).toStringAsFixed(0)} %',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
```

### Tarea 7.4 — Widget: tendencia de 6 meses

**Archivo NUEVO:** `lib/features/analytics/presentation/widgets/monthly_trend_chart.dart`

```dart
import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../transactions/data/transaction_service.dart';

/// Barras agrupadas ingresos/gastos de los últimos meses.
class MonthlyTrendChart extends StatelessWidget {
  final List<MonthTotals> data;

  const MonthlyTrendChart({super.key, required this.data});

  static const List<String> _monthNames = [
    'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
    'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic',
  ];

  String _label(String month) =>
      _monthNames[int.parse(month.substring(5, 7)) - 1];

  static String compact(double v) => v >= 1000
      ? '\$${(v / 1000).toStringAsFixed(1)}k'
      : '\$${v.toStringAsFixed(0)}';

  Widget _legend(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxVal = data.fold<double>(
      0,
      (m, t) => max(m, max(t.income, t.expense)),
    );
    if (maxVal <= 0) return const SizedBox.shrink();
    final interval = maxVal / 4;

    return AppCard(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Últimos 6 meses',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _legend(AppTheme.incomeColor, 'Ingresos'),
              const SizedBox(width: 16),
              _legend(AppTheme.expenseColor, 'Gastos'),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 220,
            child: BarChart(
              BarChartData(
                maxY: maxVal * 1.15,
                alignment: BarChartAlignment.spaceAround,
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: interval,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: AppTheme.textSecondary.withValues(alpha: 0.12),
                    strokeWidth: 1,
                  ),
                ),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => AppTheme.primaryColor,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                        BarTooltipItem(
                          '${rodIndex == 0 ? 'Ingresos' : 'Gastos'}\n'
                          '\$${rod.toY.toStringAsFixed(2)}',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 44,
                      interval: interval,
                      getTitlesWidget: (value, meta) => SideTitleWidget(
                        meta: meta,
                        child: Text(
                          compact(value),
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i >= data.length) {
                          return const SizedBox.shrink();
                        }
                        return SideTitleWidget(
                          meta: meta,
                          child: Text(
                            _label(data[i].month),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < data.length; i++)
                    BarChartGroupData(
                      x: i,
                      barsSpace: 4,
                      barRods: [
                        BarChartRodData(
                          toY: data[i].income,
                          color: AppTheme.incomeColor,
                          width: 10,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                        ),
                        BarChartRodData(
                          toY: data[i].expense,
                          color: AppTheme.expenseColor,
                          width: 10,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

### Tarea 7.5 — Widget: ritmo de gasto vs presupuesto

**Archivo NUEVO:** `lib/features/analytics/presentation/widgets/budget_pace_chart.dart`

```dart
import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../models/expense_model.dart';
import '../../../../shared/widgets/app_card.dart';
import 'monthly_trend_chart.dart';

/// Gasto acumulado del mes día a día contra la línea ideal del presupuesto.
class BudgetPaceChart extends StatelessWidget {
  final List<Expense> expenses; // gastos del mes actual
  final double budgetLimit;

  const BudgetPaceChart({
    super.key,
    required this.expenses,
    required this.budgetLimit,
  });

  @override
  Widget build(BuildContext context) {
    if (budgetLimit <= 0) return const SizedBox.shrink();

    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final daily = List<double>.filled(daysInMonth, 0);
    for (final e in expenses) {
      if (e.date.year == now.year && e.date.month == now.month) {
        daily[e.date.day - 1] += e.amount;
      }
    }

    final spots = <FlSpot>[];
    double accumulated = 0;
    for (var day = 1; day <= now.day; day++) {
      accumulated += daily[day - 1];
      spots.add(FlSpot(day.toDouble(), accumulated));
    }

    final idealToday = budgetLimit / daysInMonth * now.day;
    final isOver = accumulated > idealToday;
    final lineColor = isOver ? AppTheme.expenseColor : AppTheme.incomeColor;
    final maxY = max(budgetLimit, accumulated) * 1.1;

    return AppCard(
      margin: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isOver
                ? 'Vas por encima del ritmo de tu presupuesto'
                : 'Vas dentro del ritmo de tu presupuesto',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: lineColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Gastado: \$${accumulated.toStringAsFixed(2)} · '
            'Ideal a hoy: \$${idealToday.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                minX: 1,
                maxX: daysInMonth.toDouble(),
                minY: 0,
                maxY: maxY,
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: AppTheme.textSecondary.withValues(alpha: 0.12),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 5,
                      reservedSize: 24,
                      getTitlesWidget: (value, meta) => SideTitleWidget(
                        meta: meta,
                        child: Text(
                          value.toInt().toString(),
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 44,
                      getTitlesWidget: (value, meta) => SideTitleWidget(
                        meta: meta,
                        child: Text(
                          MonthlyTrendChart.compact(value),
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => AppTheme.primaryColor,
                    getTooltipItems: (touchedSpots) => touchedSpots
                        .map(
                          (s) => LineTooltipItem(
                            s.barIndex == 0
                                ? 'Día ${s.x.toInt()}: \$${s.y.toStringAsFixed(2)}'
                                : 'Ideal: \$${s.y.toStringAsFixed(2)}',
                            const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        )
                        .toList(),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    color: lineColor,
                    barWidth: 3,
                    dotData: FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: lineColor.withValues(alpha: 0.15),
                    ),
                  ),
                  LineChartBarData(
                    spots: [
                      FlSpot(1, budgetLimit / daysInMonth),
                      FlSpot(daysInMonth.toDouble(), budgetLimit),
                    ],
                    color: AppTheme.textSecondary,
                    barWidth: 1.5,
                    dashArray: [6, 4],
                    dotData: FlDotData(show: false),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

### Tarea 7.6 — Conectar las gráficas en `StatisticsPage`

**Archivo:** `lib/features/analytics/presentation/pages/statistics_page.dart`

1. Agrega estos imports:
   ```dart
   import '../../../../core/constants/transaction_categories.dart';
   import '../../../../models/expense_model.dart';
   import '../../../../shared/widgets/app_card.dart';
   import '../widgets/budget_pace_chart.dart';
   import '../widgets/category_donut_chart.dart';
   import '../widgets/monthly_trend_chart.dart';
   ```
   Si `expense_model.dart` o `app_card.dart` ya estaban importados, no los dupliques.
2. Junto a los campos de estado, agrega:
   ```dart
   List<MonthTotals> _monthTotals = [];
   List<Expense> _monthExpenses = [];
   ```
3. Reemplaza **todo** el método `_loadData` por esta versión. Ahora carga en paralelo y ya no deja el spinner infinito cuando no hay usuario:
   ```dart
   Future<void> _loadData() async {
     final user = _firebaseService.currentUser;
     if (user == null) {
       if (mounted) setState(() => _isLoading = false);
       return;
     }
     setState(() => _isLoading = true);

     try {
       final now = DateTime.now();
       final month = '${now.year}-${now.month.toString().padLeft(2, '0')}';

       final results = await Future.wait<dynamic>([
         _metricsService.determinePeriod(user.uid),
         _transactionService.getMonthSummary(user.uid, month: month),
         _budgetService.getBudgetStatus(user.uid),
         _transactionService.getLastMonthsTotals(user.uid),
         _transactionService.getUserExpenses(user.uid, month: month),
       ]);
       final summary = results[1] as Map<String, dynamic>;

       if (!mounted) return;
       setState(() {
         _period = results[0] as String;
         _totalIncome = (summary['totalIncomes'] ?? 0.0).toDouble();
         _totalExpense = (summary['totalExpenses'] ?? 0.0).toDouble();
         _expensesByCategory = Map<String, double>.from(
           summary['expensesByCategory'] ?? {},
         );
         _budgetStatus = results[2] as Map<String, dynamic>;
         _monthTotals = results[3] as List<MonthTotals>;
         _monthExpenses = results[4] as List<Expense>;
         _isLoading = false;
       });
     } catch (e) {
       if (mounted) {
         setState(() => _isLoading = false);
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
         );
       }
     }
   }
   ```
4. En `build`:
   - Busca:
     ```dart
     if (_budgetStatus != null && _budgetStatus!['hasBudget']) ...[
       _buildBudgetProgress(),
     ] else ...[
     ```
     y reemplázalo por:
     ```dart
     if (_budgetStatus != null && _budgetStatus!['hasBudget']) ...[
       _buildBudgetProgress(),
       BudgetPaceChart(
         expenses: _monthExpenses,
         budgetLimit: (_budgetStatus!['totalLimit'] as num).toDouble(),
       ),
     ] else ...[
     ```
   - Reemplaza `if (hasData) _buildBarChart(),` por:
     ```dart
     if (_monthTotals.any((t) => t.income > 0 || t.expense > 0))
       MonthlyTrendChart(data: _monthTotals),
     ```
   - Reemplaza `_buildPieChart(),` por:
     ```dart
     CategoryDonutChart(expensesByCategory: _expensesByCategory),
     ```
5. **Borra** completos los métodos `_buildPieChart()` y `_buildBarChart()`, y la clase `Indicator` del final del archivo. Antes de borrar `Indicator`, comprueba que no se usa en otro archivo:
   ```bash
   grep -rn "Indicator(" lib | grep -v "ProgressIndicator\|RefreshIndicator"
   ```
   Tras borrar, ese comando no debe devolver nada.
6. En `_buildBudgetProgress`, cambia `value: percentage / 100,` por `value: (percentage / 100).clamp(0.0, 1.0),`. Así la barra no se desborda si el gasto pasa el 100 %.
7. Reemplaza **todo** el método `_buildCategoryList` por:
   ```dart
   Widget _buildCategoryList() {
     final sortedCategories = _expensesByCategory.entries.toList()
       ..sort((a, b) => b.value.compareTo(a.value));
     final maxAmount = sortedCategories.isNotEmpty
         ? sortedCategories.first.value
         : 1.0;

     return Column(
       children: sortedCategories.map((entry) {
         final info = TransactionCategories.expenseInfo(entry.key);
         final share = _totalExpense > 0
             ? entry.value / _totalExpense * 100
             : 0.0;
         return AppCard(
           margin: const EdgeInsets.only(bottom: 12),
           padding: const EdgeInsets.all(16),
           child: Row(
             children: [
               Container(
                 padding: const EdgeInsets.all(10),
                 decoration: BoxDecoration(
                   color: info.color.withValues(alpha: 0.12),
                   borderRadius: BorderRadius.circular(12),
                 ),
                 child: Icon(info.icon, color: info.color, size: 20),
               ),
               const SizedBox(width: 12),
               Expanded(
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     Row(
                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
                       children: [
                         Text(
                           entry.key,
                           style: const TextStyle(
                             fontSize: 15,
                             fontWeight: FontWeight.w600,
                           ),
                         ),
                         Text(
                           '\$${entry.value.toStringAsFixed(2)}',
                           style: const TextStyle(
                             fontSize: 15,
                             fontWeight: FontWeight.bold,
                             color: AppTheme.textPrimary,
                           ),
                         ),
                       ],
                     ),
                     const SizedBox(height: 6),
                     ClipRRect(
                       borderRadius: BorderRadius.circular(5),
                       child: LinearProgressIndicator(
                         value: (entry.value / maxAmount).clamp(0.0, 1.0),
                         minHeight: 6,
                         backgroundColor: info.color.withValues(alpha: 0.12),
                         valueColor: AlwaysStoppedAnimation<Color>(info.color),
                       ),
                     ),
                     const SizedBox(height: 4),
                     Text(
                       '${share.toStringAsFixed(0)} % del total',
                       style: const TextStyle(
                         fontSize: 12,
                         color: AppTheme.textSecondary,
                       ),
                     ),
                   ],
                 ),
               ),
             ],
           ),
         );
       }).toList(),
     );
   }
   ```

### Criterios de aceptación Fase 7

- [ ] Estadísticas muestra:
  - la dona, con el total al centro; al tocar una porción cambia el centro;
  - la lista por categoría, con ícono y color iguales a los de la dona;
  - "Últimos 6 meses";
  - si hay presupuesto, el texto "Vas dentro/por encima del ritmo…" con su línea punteada.
- [ ] `grep -rn "tooltipBgColor\|axisSide" lib` sale vacío.
- [ ] `flutter analyze` / `flutter test` / `flutter build apk --debug` OK.

**Commit:** `feat(analytics): dona por categoría, tendencia de 6 meses y ritmo de presupuesto`

---

## FASE 8 — Estilo con más vida

### Tarea 8.1 — Tipografía

1. Instala el paquete:
   ```bash
   flutter pub add google_fonts
   ```
2. Verifica que el método existe en la versión instalada (no asumas el nombre):
   ```bash
   grep -rl "plusJakartaSans(" ~/.pub-cache/hosted/pub.dev/google_fonts-*/lib | head -1
   ```
   - Debe imprimir un archivo.
   - Si no imprime nada, usa `GoogleFonts.manrope()` y verifica `manrope(` con el mismo comando.
   - Si tampoco existe, **detente y pregunta**.
3. **Archivo:** `lib/core/theme/app_theme.dart`.
   - Agrega el import `import 'package:google_fonts/google_fonts.dart';`.
   - Dentro de `ThemeData(`, justo después de `useMaterial3: true,`, agrega:
     ```dart
     fontFamily: GoogleFonts.plusJakartaSans().fontFamily,
     ```

Así la fuente se aplica también a los `TextStyle` escritos a mano en las páginas, porque heredan la familia del tema. La fuente se descarga la primera vez que hay internet y luego queda en caché. Sin internet en el primer arranque se usa la fuente del sistema; no es un error.

### Tarea 8.2 — Quitar APIs de color deprecadas

1. **Archivo:** `lib/core/theme/app_theme.dart`. En `ColorScheme.light(`, borra las líneas `background: backgroundColor,` y `onBackground: textPrimary,`. Están deprecadas y `scaffoldBackgroundColor` ya cubre el fondo.
2. Reemplazo mecánico de `withOpacity`:
   ```bash
   grep -rl "withOpacity(" lib | xargs sed -i -E 's/\.withOpacity\(([^()]*)\)/.withValues(alpha: \1)/g'
   grep -rn "withOpacity(" lib
   ```
   - Si el segundo comando aún muestra líneas (casos con paréntesis anidados), cámbialas a mano: `.withOpacity(X)` → `.withValues(alpha: X)`.

### Tarea 8.3 — Tarjetas consistentes con `AppCard`

**Archivo:** `lib/features/home/presentation/pages/home_page.dart`. En `_buildTransactionItem`, el `return Container(` exterior tiene:
- `margin: const EdgeInsets.only(bottom: 8)`,
- `padding: const EdgeInsets.all(12)`,
- `decoration: BoxDecoration(color: Colors.white, borderRadius: ..., boxShadow: [...])`.

Reemplaza ese `Container` por:

```dart
return AppCard(
  margin: const EdgeInsets.only(bottom: 8),
  padding: const EdgeInsets.all(12),
  child: Row(
    // ... el mismo Row que ya existía, sin cambios
  ),
);
```

Agrega el import `import '../../../../shared/widgets/app_card.dart';`.

**Archivo:** `lib/features/analytics/presentation/pages/statistics_page.dart`. En `_buildBudgetProgress`, reemplaza el `return Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(...), child: Column(...))` por:

```dart
return AppCard(
  child: Column(
    // ... el mismo Column que ya existía, sin cambios
  ),
);
```

> No conviertas otras tarjetas en esta fase.

### Tarea 8.4 — Balance animado

**Archivo:** `lib/features/home/presentation/pages/home_page.dart`. Busca el `Text(` que muestra `'\$${totalBalance.toStringAsFixed(2)}'` (cerca de la L411) y reemplázalo completo por:

```dart
TweenAnimationBuilder<double>(
  tween: Tween<double>(end: totalBalance),
  duration: const Duration(milliseconds: 600),
  curve: Curves.easeOutCubic,
  builder: (context, value, _) => Text(
    '\$${value.toStringAsFixed(2)}',
    style: TextStyle(
      color: totalBalance >= 0 ? Colors.white : Colors.red.shade200,
      fontSize: 36,
      fontWeight: FontWeight.bold,
    ),
  ),
),
```

### Tarea 8.5 — Botón "+" destacado

**Archivo:** `lib/features/home/presentation/pages/home_page.dart`, en `build` → `BottomNavigationBar`:

1. Cambia `items: const [` por `items: [`.
2. A cada uno de los 4 `BottomNavigationBarItem` que **no** son "Agregar", ponles `const` delante.
3. Reemplaza el item `'Agregar'` completo por:
   ```dart
   BottomNavigationBarItem(
     icon: Container(
       padding: const EdgeInsets.all(10),
       decoration: const BoxDecoration(
         color: AppTheme.primaryColor,
         shape: BoxShape.circle,
       ),
       child: const Icon(Icons.add, color: Colors.white),
     ),
     label: 'Agregar',
   ),
   ```

### Criterios de aceptación Fase 8

- [ ] La app usa Plus Jakarta Sans (o Manrope).
- [ ] El balance anima al registrar una transacción.
- [ ] El "+" se ve como un botón circular destacado.
- [ ] `grep -rn "withOpacity(" lib` sale vacío.
- [ ] `flutter analyze`:
  - 0 errores, 0 warnings;
  - el número de infos `deprecated_member_use` baja respecto a la base (69).
- [ ] `flutter test` y `flutter build apk --debug` OK.

**Commit:** `style: tipografía, tarjetas consistentes, balance animado y botón + destacado`

---

## FASE 9 — Verificación final y documentación

1. Ejecuta y pega los resultados en el reporte final:
   ```bash
   flutter analyze
   flutter test
   flutter build apk --debug
   ```
2. Prueba manual completa en un dispositivo Android. Repite los criterios de aceptación de las Fases 5, 6 y 7.
3. **Archivo:** `ARCHITECTURE.md`. Agrega una sección `## ✍️ Registro inteligente` con 5–8 viñetas:
   - el flujo texto → `LocalTransactionParser` → (si falta) `TransactionExtractionService` → `QuickAddSheet` → confirmación del usuario;
   - la voz con `speech_to_text`;
   - la foto con `image_picker` + Gemini;
   - los accesos directos con `quick_actions`;
   - IA vía Firebase AI Logic + App Check (sin API key en la app);
   - el catálogo único `TransactionCategories`.
4. Reporte final al usuario:
   - qué se hizo por fase, con el hash de cada commit;
   - qué checks pasaron;
   - qué pasos HUMANO quedaron pendientes;
   - cualquier desviación del plan, con su motivo.

**Commit:** `docs: documentar registro inteligente`

---

## Fuera de alcance (no implementar sin un nuevo plan)

| Idea | Motivo para dejarla fuera |
|---|---|
| **Widget de pantalla de inicio** | En Android un widget no admite escribir texto; solo serviría como botón que abre la app. Los accesos directos de la Fase 6 cubren eso con mucho menos código nativo. Además requiere layouts nativos y, en iOS, una extensión WidgetKit. |
| **"Compartir" captura desde la app del banco** (`receive_sharing_intent`) | Su versión actual exige Kotlin 2.4.0 (el proyecto usa 2.1.0) y en iOS una Share Extension. Reevaluar tras la Fase 2. |
| **Modo oscuro** | Hay 216 colores escritos a mano en `lib/features`. Primero hay que migrarlos a tokens de `AppTheme`; es un plan propio. |
| **Confeti al desbloquear logros** | Agrega una dependencia nueva por un efecto decorativo. |
| **iOS** | El proyecto no tiene `GoogleService-Info.plist` ni `Podfile`. Configurar Firebase en iOS es un plan aparte. |
| **`ImagePicker.retrieveLostData()`** | Solo importa si Android mata la app mientras el selector está abierto. Agregarlo si se reporta pérdida de la imagen elegida. |

## Resumen de archivos

**Nuevos:**
- `lib/core/constants/transaction_categories.dart`
- `lib/shared/widgets/app_card.dart`
- `lib/core/services/shortcut_service.dart`
- `lib/features/transactions/data/transaction_draft.dart`
- `lib/features/transactions/data/local_transaction_parser.dart`
- `lib/features/transactions/data/transaction_extraction_service.dart`
- `lib/features/analytics/presentation/widgets/category_donut_chart.dart`
- `lib/features/analytics/presentation/widgets/monthly_trend_chart.dart`
- `lib/features/analytics/presentation/widgets/budget_pace_chart.dart`
- `test/local_transaction_parser_test.dart`
- `android/app/src/main/res/drawable/ic_shortcut_expense.xml`
- `android/app/src/main/res/drawable/ic_shortcut_income.xml`
- `android/app/src/main/res/raw/keep.xml`

**Modificados:**
- `pubspec.yaml`
- `lib/main.dart`
- `lib/core/constants/app_constants.dart`
- `lib/core/theme/app_theme.dart`
- `lib/core/config/env_config.dart`
- `lib/features/ai_assistant/data/gemini_service.dart`
- `lib/features/transactions/data/transaction_service.dart`
- `lib/features/transactions/presentation/widgets/quick_add_sheet.dart`
- `lib/features/transactions/presentation/pages/add_expense_page.dart`
- `lib/features/transactions/presentation/pages/add_income_page.dart`
- `lib/features/home/presentation/pages/home_page.dart`
- `lib/features/analytics/presentation/pages/statistics_page.dart`
- `lib/features/achievements/presentation/pages/achievements_page.dart`
- `android/app/src/main/AndroidManifest.xml`
- `ios/Runner/Info.plist`
- `ARCHITECTURE.md`
- (posible) `android/settings.gradle.kts`
