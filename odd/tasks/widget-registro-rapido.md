# widget-registro-rapido

Objetivo: widget Android de pantalla de inicio útil y bonito: resumen del mes (gastado, presupuesto, % usado) + acciones "+ Gasto" (principal) e "Ingreso" (secundaria), con opción de ocultar montos.
Problema: el widget actual (solo botones rojo/verde) se ve como semáforo, sin marca, y no aporta información de un vistazo.
Decisiones del usuario: diseño "Resumen + acciones" 4x2; privacidad "Opción para ocultar" montos.
Rama: `feat/widget-registro-rapido`. Commits sin coautor (pedido previo del usuario).
TDD: off (configuración previa del proyecto). Runner: `flutter test --no-pub`. Checks: `flutter analyze --no-pub --no-fatal-infos` (0 err/0 warn), `flutter test --no-pub`, `flutter build apk --debug --no-pub`, `git diff --check`.
Alcance: solo Android. Sin dependencias nuevas (puente MethodChannel + SharedPreferences nativas). Fuera de alcance: iOS, actualización desde otros dispositivos sin abrir la app.
Delivery: ask-on-risk; pronóstico ~350 líneas. Push/PR/merge: decisión del usuario.
Mirror Engram: pendiente (herramientas no disponibles). RDD: `gentle-ai` no disponible.

## Contexto (mapeo delegado)
- Gasto del mes: `HomePage._loadTransactionData` (home_page.dart:89-137) y `_applyOptimisticTransaction` (:234).
- Presupuesto: `BudgetService.getCurrentBudget(uid)` → `Budget?` (`monthlyLimit`).
- Logout: `FirebaseService.logout()` (firebase_service.dart:38), único camino.
- Menú de perfil: home_page.dart:661-697.

## Criterios de aceptación
- Widget muestra mes, monto gastado, barra y "% de $límite"; sin presupuesto muestra texto alterno.
- Con montos ocultos muestra "••••" y no muestra barra ni porcentaje.
- "+ Gasto"/"Ingreso" abren QuickAddSheet; tocar el resumen abre la app.
- Logout borra los datos del widget.
- Modo claro/oscuro con colores neutros y marca (#213149).

## Tareas
- [x] T1 Nativo: layout 4x2, provider lee SharedPreferences, MethodChannel `sagx/widget` (update/clear/hidden) en MainActivity. Ruta: delegada (writer trigger: 2+ archivos no triviales). Commit `781653b`. `flutter analyze --no-pub --no-fatal-infos`: 0 errores/0 warnings (72 infos, igual a la base); `flutter test --no-pub`: 31/31; APK debug compilado; `git diff --check` limpio. Revisión visual en dispositivo pendiente del usuario.
- [x] T2 Dart: `HomeWidgetService` + formateo puro testeado (4 pruebas); sincronizar desde HomePage; limpiar en logout. Ruta: delegada (mismo writer). Commit `0676e23` (compartido con T3 porque ambos cambian home_page.dart). `flutter analyze --no-pub --no-fatal-infos`: 0 errores/0 warnings (72 infos, igual a la base); `flutter test --no-pub`: 31/31; APK debug compilado; `git diff --check` limpio. Revisión visual en dispositivo pendiente del usuario.
- [x] T3 Toggle "Ocultar montos en widget" en menú de perfil. Ruta: delegada (mismo writer). Commit `0676e23`. `flutter analyze --no-pub --no-fatal-infos`: 0 errores/0 warnings (72 infos, igual a la base); `flutter test --no-pub`: 31/31; APK debug compilado; `git diff --check` limpio. Revisión visual en dispositivo pendiente del usuario.

## Commits previos de la rama
- `18da627` widget inicial (solo botones), `2952045` estilo píldora (reemplazado por T1). Ambos sin coautor tras reescritura local.

## Próximo paso
- Usuario: instalar (subir versión sobre +2001 o desinstalar la versión actual), quitar y volver a agregar el widget, revisar claro/oscuro, botones, toque en resumen, interruptor de ocultar y logout.
- Limitación conocida: el widget se actualiza solo cuando la app carga datos; cambios desde otro dispositivo o del presupuesto se reflejan al volver a Inicio.
- RDD/Engram no disponibles; mirror pendiente.
