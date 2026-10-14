# Retirar saldo inicial

- Objetivo: eliminar la configuración de saldo inicial; registrar el dinero inicial como un ingreso y mostrar disponible como ingresos históricos menos gastos históricos.
- Problema y motivo: las pruebas del APK mostraron confusión entre saldo inicial, disponible y resumen mensual.
- Alcance autorizado: usuario pidió «quita lo del saldo inicial» y confirmó que el dinero previamente configurado «seria un ingreso». Convertir automáticamente los importes existentes una sola vez conservando fecha e importe; retirar pantalla, accesos, mensajes y campos de modelo activos. Ingresos y gastos del resumen conservan etiquetas del mes.
- Restricciones: sin cambios remotos, sin publicación, sin duplicar ingresos ni otorgar premios por migración. Conservar datos heredados inertes para recuperación; no borrar historial. Los movimientos previos a la antigua fecha de apertura ahora también forman parte del disponible. La conversión entra en estadísticas de ingresos según su fecha, como pidió el usuario.
- Rama: `feat/remove-opening-balance`, desde `main` (`74404b536f56e1459408a84c294b58deb7d81dd4`).
- Ruta: delegada. Mapeo/preparación por `/root/review_balance_signing`: cinco archivos de producción relacionados; escritor obligatorio por dos o más archivos no triviales. Un trabajo coherente incluye migración y eliminación de la función.
- TDD: off, conservando el modo de la función original en `odd/tasks/saldo-inicial.md`; no se hereda su antigua prohibición de sesión de ejecutar pruebas. Verificación funcional ordinaria: `flutter test --no-pub`, `flutter analyze --no-pub --no-fatal-infos`, `flutter build apk --release --no-pub`, `git diff --check`.
- Entrega: `single-pr`, sin crear PR ni subir cambios. Previsión: 500–570 líneas añadidas/eliminadas, incluidas 226 de pantalla retirada y pruebas de conversión. Se mantiene una unidad coherente porque la migración debe acompañar la retirada; 400 es una guía, no un límite. Commit funcional `2f33fa8`: 558 líneas de producción/pruebas (208 añadidas, 350 eliminadas), 580 con seguimiento. Un único slice local; ninguna PR.
- RDD: disabled/unmanaged; usuario no lo habilitó, `gentle-ai` no está disponible. No iniciar revisión nativa.
- Espejo Engram: observación #20 guardada y leída completa mediante exportación CLI (MCP no disponible); topic `odd/remove-opening-balance/tasks`, proyecto `chiroless`, locator `odd/tasks/remove-opening-balance.md`.

## Tareas

- [x] ROB-1 Convertir importes heredados en ingresos mediante transacción idempotente, eliminar interfaz/modelo de saldo inicial y usar historial completo para disponible. Ruta delegada, disparadores mapping/preparation/writer. Commit `2f33fa8`. Verificados importe, fecha/mes, repetición/concurrencia, edición/eliminación sin recreación, rollback/reintento, datos inválidos, cuentas nuevas/cero sin escrituras y perfil/puntos preservados. Suite 116/116, análisis exit 0, release APK construido y firmado, diff check limpio.

## Evidencia y progreso

- Exploración con CodeGraph y mapeo delegado completada. Release tiene certificado estable; no modificar firmas ni App Check.
- Baseline: `flutter test --no-pub` terminó con 110 pruebas correctas, exit 0.
- Implementación: conversión atómica de importe positivo a `incomes/opening-balance-<uid>` con descripción «Dinero inicial», categoría «Otros» y fecha original. El marcador de perfil evita duplicación/recreación; no se leen ingresos inexistentes (compatible con reglas vigentes), no se invocan premios. Campos heredados permanecen inertes para recuperación. Home usa las opciones existentes de propagación de error y ofrece Reintentar sin exponer un disponible parcial.
- Checks observados: seis pruebas específicas y `flutter test --no-pub` completo 116/116, exit 0. El primer intento del padre quedó bloqueado por escritura de caché Flutter en sandbox; repetido con permiso y exitoso. `flutter analyze --no-pub --no-fatal-infos`: exit 0, 75 infos, cero errores/advertencias. Format verificado sin cambios y `git diff --check` limpio. `flutter build apk --release --no-pub`: exit 0, APK 68.2 MB; avisos de futura incompatibilidad Gradle 8.12/AGP 8.9.1/Kotlin y plugins, sin fallos.
- Firma verificada con `apksigner verify --print-certs`: exit 0, SHA-256 `70b12b0707196e2a58ffa8c3481299f4be5cddb14a083221c3da340e9175825a`, coincidente con la segunda huella de la captura. Artefacto `build/app/outputs/flutter-apk/app-release.apk`.
- Pendientes: prueba visual/en dispositivo y migración con Firebase real (no ejecutadas; ningún acceso remoto). Revisión nativa disabled/unmanaged. Espejo local #20 actualizado con el documento completo.
- Próximo paso: instalar el APK release nuevo en un dispositivo de pruebas y comprobar la aparición única de «Dinero inicial», el disponible y los totales del mes.
