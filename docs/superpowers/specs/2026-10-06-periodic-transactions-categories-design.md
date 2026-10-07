# Diseño: transacciones periódicas y categorías editables

## Objetivo

Registrar automáticamente gastos e ingresos periódicos, permitir administrar categorías de ambos tipos y facilitar la edición/eliminación de movimientos desde Inicio.

## Diseño

### Transacciones periódicas

Agregar una entidad de serie periódica con propietario, tipo (gasto/ingreso), monto, categoría, descripción, fecha inicial, frecuencia (semanal, mensual o anual), fecha final opcional y estado activo. Al iniciar sesión o abrir la app, reconciliar las series del usuario y crear las ocurrencias cuya fecha ya llegó. Cada ocurrencia debe quedar asociada a su serie y fecha programada, con clave estable/registro de ocurrencias para que reintentos y aperturas repetidas no dupliquen movimientos. Las ocurrencias se guardan en las colecciones de gastos/ingresos existentes para conservar consultas, estadísticas y balance actuales.

Agregar a los formularios existentes una opción de periodicidad. El usuario configura la serie junto con el primer movimiento. Editar o borrar un movimiento generado desde Inicio modifica o elimina solo esa ocurrencia; la serie continúa y el registro de ocurrencias evita recrear una que fue eliminada.

### Categorías

Persistir las categorías de cada usuario por separado para gastos e ingresos. Inicializar con las categorías estáticas existentes para mantener el comportamiento de usuarios actuales. Agregar un acceso de administración desde Inicio para agregar/eliminar categorías. Impedir eliminar la última categoría del tipo correspondiente. Al eliminar una categoría, mantener intactos los valores de transacciones históricas; los movimientos continúan mostrando el nombre original.

Usar las categorías almacenadas en formularios, quick-add/extracción y estadísticas. Mantener compatibilidad con documentos existentes cuyos campos categoría/fuente sean texto.

### Acciones desde Inicio

Mantener presionada una tarjeta abre una hoja de acciones con editar y eliminar. Editar navega a los formularios actuales pasando el modelo. Eliminar muestra confirmación y usa los servicios existentes; el inicio se recarga después del éxito.

## Alternativas de ejecución para recurrencias

1. Reconciliar al abrir la app o iniciar sesión (seleccionada): usa el flujo de cliente ya existente, recupera ocurrencias vencidas sin necesitar tareas de servidor y persiste una clave idempotente. Una serie se procesa cuando el usuario vuelve a abrir la app.
2. Ejecutar en segundo plano con una tarea del dispositivo: podría registrar sin abrir la app, pero depende de permisos, límites de ejecución del SO y configuración por plataforma que el proyecto no tiene hoy.

## Límites y compatibilidad

- El cambio es por usuario autenticado y no requiere migrar los nombres guardados en transacciones históricas.
- Las ocurrencias vencidas se generan en orden hasta hoy, respetando inicio y fin.
- Se deben definir de forma determinista las fechas de meses cortos y cambios de año en el cálculo y cubrirlas con pruebas.
- La generación solo está garantizada cuando se abre la app; no se asume ejecución en segundo plano.

## Verificación

- Pruebas de calendario: semanal, mensual, anual, fechas límite y fin de serie.
- Pruebas de idempotencia ante aperturas/reintentos concurrentes y ocurrencia eliminada.
- Pruebas de categorías: valores iniciales, aislamiento por usuario, agregar, borrar y protección de la última.
- Pruebas de acciones de Inicio y suite `flutter test --no-pub`.
- `flutter analyze --no-pub --no-fatal-infos`, `flutter build apk --debug --no-pub` y `git diff --check`.
