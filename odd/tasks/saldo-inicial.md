# Saldo inicial

- Objetivo: permitir que cada usuario registre el dinero disponible al inicio de su seguimiento y que Inicio muestre ese monto más los ingresos menos los gastos desde la fecha elegida.
- Problema: Inicio muestra actualmente el neto de movimientos del mes actual; no hay un monto de apertura para organizarse con dinero que ya se tenía.
- Por qué: el usuario quiere definir con cuánto dinero cuenta y organizarse desde esa base.
- Alcance autorizado: guardar importe y fecha de apertura en el perfil; permitir configurarlos y editarlos; mostrar en Inicio el saldo calculado desde esa fecha. La fecha es inclusiva. Los ingresos y gastos mensuales del resumen conservan su significado actual. Para perfiles antiguos sin saldo configurado, usar importe cero y fecha actual.
- Restricciones: no contar el saldo como ingreso; no alterar presupuestos ni movimientos existentes. La fecha e importe se etiquetan como saldo disponible en esa fecha para que el usuario no lo confunda con un ingreso.
- Rama: `feat/saldo-inicial`, creada desde `feat/periodic-transactions-categories` (`52cf930`).
- TDD: deshabilitado según configuración previa registrada en `odd/tasks/claridad-financiera.md`; runner del proyecto `flutter test --no-pub` (no ejecutar ni añadir pruebas automatizadas sin petición explícita). Checks aplicables: `flutter analyze --no-pub --no-fatal-infos`, `flutter build apk --debug --no-pub`, `git diff --check`.
- Ruta: delegada. Evidencia: el cambio requiere coordinar el modelo y lectura/escritura de perfil, formulario de perfil, consulta/cálculo de Inicio y comprobaciones (4+ archivos); el disparador de escritor aplica al tocar 2+ archivos no triviales. Mapeo de solo lectura delegado a `/root/opening_balance_mapping`.
- Estrategia de entrega: `ask-on-risk` (por defecto). Forecast inicial: ~250 líneas editadas; commit de trabajo `2ea7ca1` registró 238 líneas añadidas/eliminadas (incluye el documento de tarea), por debajo del umbral de entrega.

## Tareas

- [x] SI-1 Persistir y editar importe/fecha de apertura en el perfil; Inicio calcula el saldo desde esa fecha inclusiva y mantiene totales/resumen mensual. Ruta delegada: writer por cambios coordinados en 5 archivos no triviales. Commit `2ea7ca1`. `flutter analyze --no-pub --no-fatal-infos`: sin errores ni advertencias; 82 mensajes informativos. `flutter build apk --debug --no-pub`: APK generado; Gradle/AGP/Kotlin muestran avisos de compatibilidad futura. `git diff --check`: limpio. No se añadieron ni ejecutaron pruebas automatizadas por instrucción de sesión. Revisión visual/dispositivo y Firestore real pendientes.

## Progreso y evidencia

- Exploración: CodeGraph y mapeo delegado identificaron `AppUser`, `UserService`, `EditProfilePage`, `HomePage` y `TransactionService`. Las consultas mensuales de movimientos no sirven para un saldo desde una fecha arbitraria; Inicio necesitará el historial completo para calcularlo.
- Espejo Engram: pendiente; las herramientas de memoria/Engram no están disponibles en esta sesión. Mantener este archivo como copia local hasta poder sincronizar.
- Próximo paso: sincronizar el espejo Engram cuando la herramienta esté disponible; validar visualmente y con Firestore en dispositivo.
