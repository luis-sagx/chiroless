# Retirar saldo inicial

- Objetivo: eliminar la configuración de saldo inicial; registrar el dinero inicial como un ingreso y mostrar disponible como ingresos históricos menos gastos históricos.
- Problema y motivo: las pruebas del APK mostraron confusión entre saldo inicial, disponible y resumen mensual.
- Alcance autorizado: usuario pidió «quita lo del saldo inicial» y confirmó que el dinero previamente configurado «seria un ingreso». Convertir automáticamente los importes existentes una sola vez conservando fecha e importe; retirar pantalla, accesos, mensajes y campos de modelo activos. Ingresos y gastos del resumen conservan etiquetas del mes.
- Restricciones: sin cambios remotos, sin publicación, sin duplicar ingresos ni otorgar premios por migración. Conservar datos heredados inertes para recuperación; no borrar historial. Los movimientos previos a la antigua fecha de apertura ahora también forman parte del disponible. La conversión entra en estadísticas de ingresos según su fecha, como pidió el usuario.
- Rama: `feat/remove-opening-balance`, desde `main` (`74404b536f56e1459408a84c294b58deb7d81dd4`).
- Ruta: delegada. Mapeo/preparación por `/root/review_balance_signing`: cinco archivos de producción relacionados; escritor obligatorio por dos o más archivos no triviales. Un trabajo coherente incluye migración y eliminación de la función.
- TDD: off, conservando el modo de la función original en `odd/tasks/saldo-inicial.md`; no se hereda su antigua prohibición de sesión de ejecutar pruebas. Verificación funcional ordinaria: `flutter test --no-pub`, `flutter analyze --no-pub --no-fatal-infos`, `flutter build apk --release --no-pub`, `git diff --check`.
- Entrega: `single-pr`, sin crear PR ni subir cambios. Previsión: 500–570 líneas añadidas/eliminadas, incluidas 226 de pantalla retirada y pruebas de conversión. Se mantiene una unidad coherente porque la migración debe acompañar la retirada; 400 es una guía, no un límite. Acumulado: pendiente.
- RDD: disabled/unmanaged; usuario no lo habilitó, `gentle-ai` no está disponible. No iniciar revisión nativa.
- Espejo Engram: observación #20 guardada y leída completa mediante exportación CLI (MCP no disponible); topic `odd/remove-opening-balance/tasks`, proyecto `chiroless`, locator `odd/tasks/remove-opening-balance.md`.

## Tareas

- [ ] ROB-1 Convertir importes heredados en ingresos mediante transacción idempotente, eliminar interfaz/modelo de saldo inicial y usar historial completo para disponible. Ruta delegada, disparadores mapping/preparation/writer. Verificar importe, fecha/mes, repetición, ausencia de duplicados y rollback; ejecutar suite, análisis, build release y diff check. Cerrar con commit Conventional Commit y registrar identidad.

## Evidencia y progreso

- Exploración con CodeGraph y mapeo delegado completada. Release tiene certificado estable; no modificar firmas ni App Check.
- Baseline: `flutter test --no-pub` terminó con 110 pruebas correctas, exit 0.
- Próximo paso: escritor delegado implementa ROB-1; comprobar diff, suite completa y APK release antes de commit.
