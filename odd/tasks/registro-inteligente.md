# registro-inteligente

Objetivo: registro de ingresos/gastos fácil (texto libre, voz, foto, atajos), gráficas claras, estilo con más vida.
Fuente de verdad: `PLAN_REGISTRO_INTELIGENTE.md` (fases 0–9). Rama: `feat/registro-inteligente`.
TDD: off salvo Fase 3 (plan lo exige). Runner: `flutter test`. Checks por fase: `flutter analyze` (0 err/0 warn), `flutter test`, desde Fase 2 `flutter build apk --debug`.
Autorizado: Fases 0–9 por el pedido actual de continuar las fases restantes inline en esta rama. D1: no está en Play Store, solo local; a futuro sí. La configuración de Firebase Console y la prueba en dispositivo dependen del usuario.
Delivery: ask-on-risk. Push/PR/merge: decisión del usuario. Commits sin coautor (pedido del usuario).
Ruta: inline por instrucción explícita del usuario, aunque varias fases abarcan múltiples archivos. Pronóstico: unas 1800–2400 líneas modificadas, excluidos archivos generados. Mirror Engram pendiente: sus herramientas no están disponibles en este entorno.

## Tareas
- [x] 0 Fase 0 — commit 7aac48e
- [x] 1 Fase 1 — commit eb3de6a (ruta: inline por pedido del usuario; analyze 0 err/0 warn, test ok)
- [ ] 2 Fase 2 — código y APK debug verificados en commit 2bd86b5; pendiente Firebase Console y prueba de chat en dispositivo. `flutter test` pasó, análisis: 0 errores/0 warnings y 140 infos; APK debug compiló. Desviación: Kotlin 2.3.0 y `compilerOptions` por incompatibilidad de Gradle. Ruta inline por pedido del usuario.
- [x] 3 Fase 3 — parser local (TDD). RED: faltaba `local_transaction_parser.dart`; GREEN: `flutter test --no-pub` 12/12. Análisis: 0 errores/0 warnings, 140 infos. Ruta inline por pedido del usuario; commit registrado abajo.
- [x] 4 Fase 4 — servicio de extracción IA texto/foto; `flutter analyze --no-pub --no-fatal-infos` 0 errores/0 warnings (141 infos), `flutter test --no-pub` 12/12, APK debug compilado. Prueba real de IA pendiente de Firebase Console y UI (fase 5). Ruta inline por pedido del usuario; commit registrado abajo.
- [ ] 5 Fase 5 — código integrado (texto, voz, foto, home y refresco de estadísticas); `flutter analyze --no-pub --no-fatal-infos` 0 errores/0 warnings (135 infos), `flutter test --no-pub` 12/12 y APK debug compilado. Pendiente prueba manual Android (no hay dispositivo conectado) y Firebase Console. El cambio supera la heurística de 400 líneas porque reemplaza el sheet completo según el plan. El guardado ahora espera a Firestore para evitar falsos éxitos y refrescos prematuros. Ruta inline por pedido del usuario; commit registrado abajo.
- [ ] 6 Fase 6 — accesos directos implementados; `flutter analyze --no-pub --no-fatal-infos` 0 errores/0 warnings (136 infos), `flutter test --no-pub` 12/12, APK debug compilado. Pruebas de pulsación y arranque desde Android pendientes: no hay dispositivo conectado. Ruta inline por pedido del usuario; commit registrado abajo.
- [ ] 7 Fase 7 — gráficas
- [ ] 8 Fase 8 — estilo
- [ ] 9 Fase 9 — verificación final + docs

## Evidencia de commits de esta continuación
- Fase 2: `2bd86b5`.
- Fase 3: `e23ba1e`.
- Fase 4: `5739a08`.
- Fase 5: `7a4f8b4`.
