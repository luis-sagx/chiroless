# Saldo inicial

- Objetivo: permitir que cada usuario registre el dinero disponible al inicio de su seguimiento y que Inicio muestre ese monto más los ingresos menos los gastos desde la fecha elegida.
- Problema: Inicio muestra actualmente el neto de movimientos del mes actual; no hay un monto de apertura para organizarse con dinero que ya se tenía.
- Por qué: el usuario quiere definir con cuánto dinero cuenta y organizarse desde esa base.
- Alcance autorizado: guardar importe y fecha de apertura en el perfil; permitir configurarlos y editarlos; mostrar en Inicio el saldo calculado desde esa fecha. La fecha es inclusiva. Los ingresos y gastos mensuales del resumen conservan su significado actual. Para perfiles antiguos sin saldo configurado, sugerir configuración explícita desde Inicio, con importe cero y fecha actual como base segura hasta que el usuario guarde su saldo.
- Restricciones: no contar el saldo como ingreso; no alterar presupuestos ni movimientos existentes. La fecha e importe se etiquetan como saldo disponible en esa fecha para que el usuario no lo confunda con un ingreso.
- Rama: `feat/saldo-inicial`, creada desde `feat/periodic-transactions-categories` (`52cf930`).
- TDD: deshabilitado según configuración previa registrada en `odd/tasks/claridad-financiera.md`; runner del proyecto `flutter test --no-pub` (no ejecutar ni añadir pruebas automatizadas sin petición explícita). Checks aplicables: `flutter analyze --no-pub --no-fatal-infos`, `flutter build apk --debug --no-pub`, `git diff --check`.
- Ruta: delegada. Evidencia: el cambio requiere coordinar el modelo y lectura/escritura de perfil, formulario de perfil, consulta/cálculo de Inicio y comprobaciones (4+ archivos); el disparador de escritor aplica al tocar 2+ archivos no triviales. Mapeo de solo lectura delegado a `/root/opening_balance_mapping`.
- Estrategia de entrega: `ask-on-risk` (por defecto). Commit de trabajo inicial `2ea7ca1`: 257 líneas modificadas (238 añadidas, 19 eliminadas). El arreglo de descubribilidad suma unas 43 líneas editadas; acumulado aproximado 300, aún bajo el umbral de entrega.
- RDD: `gentle-ai review mode status` no está disponible (`gentle-ai` no está instalado en esta sesión); no se ejecutó una revisión nativa. Sin confirmación de modo no se reclama autorización ni resultado de review.

## Tareas

- [x] SI-1 Persistir y editar importe/fecha de apertura; Inicio calcula el saldo desde esa fecha inclusiva, mantiene totales/resumen mensual y ahora muestra «Configurar saldo inicial» para cuentas sin configurar. Ruta delegada por 4+ archivos y writer. Causa confirmada: cuentas antiguas carecen de campos de apertura y se leen como $0/fecha actual; el editor solo estaba en Perfil → Editar perfil. Se agregó `openingBalanceConfigured` para distinguir no configurado de configurado en cero. Commit funcional inicial `2ea7ca1`; corrección de descubribilidad pendiente de commit. `flutter analyze --no-pub --no-fatal-infos`: sin errores ni advertencias, 82 mensajes informativos. `flutter build apk --debug --no-pub`: correcto; avisos futuros de Gradle/AGP/Kotlin. `git diff --check`: limpio. No se añadieron ni ejecutaron pruebas automatizadas por instrucción de sesión. Revisión visual/dispositivo y Firestore real pendientes.

## Progreso y evidencia

- Exploración: CodeGraph y mapeo delegado identificaron `AppUser`, `UserService`, `EditProfilePage`, `HomePage` y `TransactionService`. Las consultas mensuales de movimientos no sirven para un saldo desde una fecha arbitraria; Inicio necesitará el historial completo para calcularlo.
- Depuración y corrección: `UserService` asigna importe cero y fecha actual a documentos antiguos sin campos; `_loadTransactionData` filtra movimientos desde esa fecha. El campo estaba en Perfil → Editar perfil. Se agregó un acceso directo visible en la tarjeta de Inicio y un indicador persistido de configuración; el editor establece el indicador incluso si el monto elegido es cero.
- Espejo Engram: pendiente; las herramientas de memoria/Engram no están disponibles en esta sesión. Mantener este archivo como copia local hasta poder sincronizar.
- Próximo paso: registrar el commit de corrección; espejo Engram, revisión visual/dispositivo y prueba con Firestore real siguen pendientes.
