# Claridad financiera

Objetivo: permitir corregir movimientos y hacer que las estadísticas y el presupuesto respondan preguntas útiles con pocas acciones.
Problema: ingresos y gastos no tienen acciones visibles de edición/eliminación; Estadísticas repite el balance de Inicio, muestra un indicador interno «Periodo post», deja ambiguo el alcance de gastos y amontona días en el eje del ritmo presupuestario. El presupuesto actual es mensual y no se repite.
Alcance autorizado: cambios locales de interfaz, lógica y pruebas para los pedidos del usuario. No incluye publicación remota.
Restricciones: conservar una experiencia rápida y sencilla; confirmar borrados, comprobar el resultado de Firestore y refrescar cifras; evitar consultas históricas sin límite. El comportamiento de repetición de presupuesto depende de la respuesta del usuario.
Rama: `feat/claridad-financiera`. TDD efectivo: off, por configuración previa en `odd/tasks/widget-registro-rapido.md` y `odd/tasks/registro-inteligente.md`; runner `flutter test --no-pub`. Checks aplicables: `flutter analyze --no-pub --no-fatal-infos`, `flutter test --no-pub`, `flutter build apk --debug --no-pub`, `git diff --check`.
Engram: mirror `odd/claridad-financiera/tasks` pendiente: herramientas no disponibles. RDD: deshabilitado/no gestionado; `gentle-ai` no disponible.
Entrega: estrategia `single-pr` por cohesión de cambios de un mismo flujo; sin PR autorizado. Pronóstico: 550–850 líneas modificadas, excluidos archivos generados. Cada tarea tendrá commit propio; registrar conteo real y revisar política de PR antes de crear uno.

## Tareas

- [x] T1 Movimientos: edición y eliminación de ingresos/gastos desde un listado mensual accesible desde Inicio, con confirmación de borrado, validación, mensajes de error y actualización de Inicio/Estadísticas al volver. Ruta delegada: mapeo de 4+ archivos, preparación de escritura y 2+ archivos no triviales. Cambios de fecha actualizan la clave mensual. `flutter test --no-pub`: 33 pruebas aprobadas (incluidas 2 de cambio de mes); `flutter analyze --no-pub --no-fatal-infos`: 0 errores y 0 warnings, 72 infos preexistentes; APK debug compilado antes de un pequeño guard de versión de carga; `git diff --check`: limpio. Prueba visual/Firestore en dispositivo pendiente. Commit `606d6de` (419 líneas modificadas).
- [ ] T2 Estadísticas: retirar balance duplicado y «Periodo post», rotular que categorías/gastos son del mes actual, permitir elegir un rango acotado de meses para tendencia y resolver solapamiento del eje X del ritmo. Ruta delegada: 2+ archivos no triviales. Criterio: títulos y periodos visibles, selector funcional, ejes legibles. Checks: pruebas funcionales, análisis y compilación.
- [ ] T3 Presupuesto: explicar vigencia mensual, dar acceso a editarlo y aplicar la decisión del usuario sobre repetición entre meses. Ruta pendiente de decisión; delegada si toca 2+ archivos no triviales. Criterio: el usuario entiende qué presupuesto rige y puede cambiarlo con pocos toques. Checks: pruebas funcionales, análisis y compilación.

## Progreso y evidencia

- Exploración: `TransactionService` ya implementa update/delete; `Expense` e `Income` fijan `month` desde `date` al construir y su `copyWith(date:)` conserva el mes anterior. Categorías y gastos en Estadísticas provienen del mes actual; tendencia consulta dos colecciones por mes. `MetricsService.determinePeriod` devuelve siempre `post`.
- Próximo paso: T2; se espera la decisión de repetición del presupuesto.
