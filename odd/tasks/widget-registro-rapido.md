# widget-registro-rapido

Objetivo: widget Android de pantalla de inicio útil y bonito: resumen del mes (gastado, presupuesto, % usado) + acciones "+ Gasto" (principal) e "Ingreso" (secundaria), con opción de ocultar montos.
Problema: el widget actual (solo botones rojo/verde) se ve como semáforo, sin marca, y no aporta información de un vistazo.
Decisiones del usuario: diseño "Resumen + acciones" 4x2; privacidad "Opción para ocultar" montos.
Rama original: `feat/widget-registro-rapido`. Esta corrección está autorizada directamente en `main` por el usuario.
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
- [x] T4 Recuperación del widget al desbloquear y refresco periódico de respaldo. Alcance autorizado: registrar dinámicamente `ACTION_USER_PRESENT` durante la vida de `MainActivity`, volver a renderizar todas las instancias desde SharedPreferences al recibirlo, y habilitar el intervalo mínimo de actualización de Android (30 minutos); sin servicio persistente, consulta Firebase ni cambio de contenido. Criterios: al desbloquear con el proceso activo, el widget repinta datos locales; si Android termina el proceso, el intervalo periódico vuelve a invocar `onUpdate` como respaldo. Ruta: delegada (writer trigger: cambio coordinado en MainActivity y configuración XML). TDD: off (configuración existente); runner registrado: `flutter test --no-pub`. Checks observados: `flutter analyze --no-pub --no-fatal-infos` sin errores/advertencias (71 infos); `flutter build apk --debug --no-pub` correcto; `git diff --check` limpio. Pruebas automatizadas no ejecutadas (no solicitadas). Commit pendiente. Mirror Engram pendiente: herramientas no disponibles.

## Commits previos de la rama
- `18da627` widget inicial (solo botones), `2952045` estilo píldora (reemplazado por T1). Ambos sin coautor tras reescritura local.

## Próximo paso
- Usuario: instalar (subir versión sobre +2001 o desinstalar la versión actual), quitar y volver a agregar el widget, revisar claro/oscuro, botones, toque en resumen, interruptor de ocultar y logout.
- Limitación conocida: `ACTION_USER_PRESENT` refresca de inmediato mientras el proceso de la app siga activo; si Android lo termina, la recuperación depende del refresco periódico de 30 minutos. Cambios desde otro dispositivo o del presupuesto se reflejan al volver a Inicio.
- Próximo paso T4: instalar el APK nuevo y comprobar el refresco al desbloquear; también validar que el respaldo actualiza el widget tras terminar el proceso de la app.
- RDD/Engram no disponibles; mirror pendiente.
