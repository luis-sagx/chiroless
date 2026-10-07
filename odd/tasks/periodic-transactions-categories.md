# Transacciones periódicas y categorías editables

Objetivo: permitir registrar gastos e ingresos periódicos automáticamente, administrar sus categorías y editar o eliminar movimientos desde Inicio.

Problema: los modelos solo representan movimientos individuales, las categorías son listas fijas y las tarjetas recientes de Inicio no exponen acciones.

Alcance autorizado: cambios locales a modelos, persistencia, generación idempotente de recurrencias, categorías por usuario y sus consumidores, formularios, Inicio y pruebas/documentación necesarias. Una recurrencia genera sus ocurrencias vencidas al abrir la app/iniciar sesión; frecuencias semanal, mensual y anual; fin opcional. Editar o eliminar una ocurrencia desde Inicio solo afecta a esa ocurrencia, la serie continúa. Categorías iniciales proceden de las listas actuales; cada tipo conserva al menos una categoría. Eliminar una categoría no modifica transacciones históricas.

Restricciones: preservar historial y comportamiento de transacciones existentes; evitar duplicar ocurrencias tras reiniciar/reabrir la app; aplicar cambios únicamente al usuario autenticado; no hacer operaciones remotas ni publicar.

Rama: `feat/periodic-transactions-categories` (desde `main`). TDD efectivo: deshabilitado, fuente `odd/tasks/claridad-financiera.md`; runner `flutter test --no-pub`. Checks aplicables: `flutter test --no-pub`, `flutter analyze --no-pub --no-fatal-infos`, `flutter build apk --debug --no-pub`, `git diff --check`.

Engram: mirror `odd/periodic-transactions-categories/tasks` pendiente; las herramientas de memoria no están disponibles en esta sesión. RDD: deshabilitado/no gestionado según configuración documentada del proyecto; no se ejecuta revisión nativa.

Entrega: estrategia `single-pr`, siguiendo la decisión documentada para cambios cohesionados del mismo proyecto; no se creará PR sin autorización posterior. Pronóstico inicial: 800–1100 líneas modificadas, generados excluidos. No se eliminarán ni reducirán líneas para cumplir una cifra heurística.

## Criterios de aceptación

- Las recurrencias semanales, mensuales y anuales crean en Firestore una ocurrencia por fecha vencida hasta hoy, sin duplicados entre aperturas; respetan fecha de inicio y fecha de fin opcional.
- Gastos e ingresos pueden configurarse como periódicos desde sus formularios; sus ocurrencias conservan monto, categoría/fuente y descripción configurados.
- Las categorías de gasto e ingreso se cargan por usuario, incluyen las categorías existentes para usuarios actuales y se pueden agregar o eliminar; no se puede eliminar la última de cada tipo.
- Las categorías dinámicas se usan en los formularios y demás flujos actuales que dependen de categorías; las categorías históricas eliminadas siguen visibles en los movimientos.
- Mantener presionada una tarjeta de movimiento en Inicio permite editarla o eliminarla; borrar pide confirmación y ambas operaciones actualizan Inicio al terminar.

## Tareas

- [ ] T1 Periodicidad: modelar series/ocurrencias, persistencia y reconciliación idempotente al iniciar sesión; conectar formularios. Ruta: delegada directa; evidencia: el flujo toca modelos, servicio Firestore, carga de sesión y dos formularios (>2 archivos no triviales). Implementación terminada; `flutter analyze --no-pub --no-fatal-infos` pasó (0 errores, 75 infos) y `git diff --check` pasó. Pruebas de cálculo/deduplicación no agregadas ni ejecutadas por instrucción del entorno; quedan como verificación pendiente. Commit de unidad: `f89c6df`.
- [ ] T2 Categorías: persistir categorías por usuario, inicializar valores por defecto y añadir administración; sustituir las listas fijas en selección, extracción rápida y estadísticas. Ruta: delegada directa; evidencia: el mapa de CodeGraph encontró consumidores en más de cuatro archivos. Implementación terminada; `flutter analyze --no-pub --no-fatal-infos` pasó (0 errores, 80 infos) y `git diff --check` pasó. Pruebas de protección de mínimo, aislamiento e inicialización no agregadas ni ejecutadas por instrucción del entorno; quedan pendientes. Commit de unidad: `d24b494`.
- [ ] T3 Acciones en Inicio: añadir menú contextual por pulsación larga con edición y borrado confirmado, refresco de datos y tratamiento de ocurrencias periódicas. Ruta: delegada directa; evidencia: Inicio, páginas de edición y servicio de transacciones son archivos no triviales distintos. Implementación terminada; análisis integrado pasó (0 errores, 80 infos), `flutter build apk --debug --no-pub` pasó y `git diff --check` pasó. Pruebas widget no agregadas ni ejecutadas por instrucción del entorno; quedan pendientes.

## Progreso y evidencia

- Exploración realizada con CodeGraph y mapeo delegado de solo lectura: los formularios de alta ya aceptan modelos existentes para editar; `TransactionService` tiene update/delete; Inicio limita las tarjetas recientes a cinco y no tiene gestos de edición/eliminación; categorías actuales son estáticas y usadas también por quick-add/extracción/estadísticas; no hay recurrencias implementadas.
- Diseño aprobado por el usuario: registro automático de ocurrencias vencidas; categorías dinámicas por usuario con una mínima por tipo; acciones de Inicio mediante pulsación larga.
- El usuario indicó continuar directamente con la implementación, por lo que se omitió la revisión formal de la especificación.
- T1 implementada por escritor delegado; cambios revisados mediante CodeGraph. Commit `f89c6df`. Las pruebas automatizadas siguen pendientes/no ejecutadas; no se marcará T1 como cerrada sin esa evidencia.
- T2 implementada por escritora delegada; cambios revisados mediante CodeGraph. Commit `d24b494`. Las pruebas automatizadas siguen pendientes/no ejecutadas; no se marcará T2 como cerrada sin esa evidencia. Las reglas de categorías son por propietario, pero aún no se validaron con Firestore Emulator.
- T3 implementada por escritor delegado; cambios revisados mediante CodeGraph; commit de unidad pendiente. Las pruebas automatizadas siguen pendientes/no ejecutadas; no se marcará T3 como cerrada sin esa evidencia.
- Verificación integrada: `flutter analyze --no-pub --no-fatal-infos` pasó (80 infos, 0 errores); `flutter build apk --debug --no-pub` pasó con advertencias existentes sobre Gradle/AGP/Kotlin; `git diff --check` pasó. No se agregaron ni ejecutaron pruebas automatizadas por instrucción del entorno.
- Próximo paso: registrar el commit T3 y entregar el resultado con las pruebas pendientes y el mirror Engram señalado. No se hizo trabajo remoto ni se creó PR.
