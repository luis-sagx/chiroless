# registro-inteligente

Objetivo: registro de ingresos/gastos fácil (texto libre, voz, foto, atajos), gráficas claras, estilo con más vida.
Fuente de verdad: `PLAN_REGISTRO_INTELIGENTE.md` (fases 0–9). Rama: `feat/registro-inteligente`.
TDD: off salvo Fase 3 (plan lo exige). Runner: `flutter test`. Checks por fase: `flutter analyze` (0 err/0 warn), `flutter test`, desde Fase 2 `flutter build apk --debug`.
Autorizado: Fases 0–9 por el pedido actual de continuar las fases restantes inline en esta rama. D1: no está en Play Store, solo local; a futuro sí. La configuración de Firebase Console y la prueba en dispositivo dependen del usuario.
Delivery: ask-on-risk; 2350 líneas acumuladas aprox. (sin lock, registrantes generados ni seguimiento). La estrategia de PR encadenados queda pendiente para cuando el usuario quiera publicar; esta solicitud solo autoriza trabajar en la rama. Push/PR/merge: decisión del usuario. Commits sin coautor (pedido del usuario).
Ruta: inline por instrucción explícita del usuario, aunque varias fases abarcan múltiples archivos. Pronóstico: unas 1800–2400 líneas modificadas, excluidos archivos generados. Mirror Engram pendiente: sus herramientas no están disponibles en este entorno.

## Tareas
- [x] 12 Compactar registro rápido tras prueba visual del usuario: explicación breve, ejemplo corto, acciones explícitas, categorías en selector compacto con iconos. Ruta inline por pedido del usuario; commit `3773ed8`. `flutter analyze --no-pub --no-fatal-infos`: 0 errores/0 warnings (72 infos), `flutter test --no-pub`: 12/12, APK debug compilado, detector de UI `[]`, `git diff --check` limpio. Revisión visual Android pendiente del usuario. TDD off por configuración previa; runner `flutter test --no-pub`.
- [x] 10 Claridad del registro rápido: texto y voz con acciones explícitas, ocultar entrada de foto/cámara, selección de categoría sin visto. Ruta inline por instrucción del usuario; commit `3742ecb`. `flutter analyze --no-pub --no-fatal-infos`: 0 errores/0 warnings, 80 infos; `flutter test --no-pub`: 12/12; APK debug compilado; detector de UI: `[]`. Revisión visual Android pendiente del usuario.
- [x] 11 Retirar encuestas inicial y final del flujo: registro directo a Inicio, sin acceso a encuesta final; código de encuesta sin consumidores eliminado. Ruta inline por instrucción del usuario; commit `a9e32a4`. Sin referencias a `SurveyPage`, `SurveyService` ni `SurveyResponse` en `lib`; pruebas 12/12, análisis 0 errores/0 warnings (72 infos), APK debug compilado, `git diff --check` limpio. Prueba manual del flujo de registro pendiente; hay un Android conectado, pero no se instaló ni manejó el dispositivo durante esta tarea. El panel de investigador, que no fue parte del pedido, conserva métricas históricas PRE/POST.
- [x] 0 Fase 0 — commit 7aac48e
- [x] 1 Fase 1 — commit eb3de6a (ruta: inline por pedido del usuario; analyze 0 err/0 warn, test ok)
- [ ] 2 Fase 2 — código y APK debug verificados en commit 2bd86b5; pendiente Firebase Console y prueba de chat en dispositivo. `flutter test` pasó, análisis: 0 errores/0 warnings y 140 infos; APK debug compiló. Desviación: Kotlin 2.3.0 y `compilerOptions` por incompatibilidad de Gradle. Ruta inline por pedido del usuario.
- [x] 3 Fase 3 — parser local (TDD). RED: faltaba `local_transaction_parser.dart`; GREEN: `flutter test --no-pub` 12/12. Análisis: 0 errores/0 warnings, 140 infos. Ruta inline por pedido del usuario; commit registrado abajo.
- [x] 4 Fase 4 — servicio de extracción IA texto/foto; `flutter analyze --no-pub --no-fatal-infos` 0 errores/0 warnings (141 infos), `flutter test --no-pub` 12/12, APK debug compilado. Prueba real de IA pendiente de Firebase Console y UI (fase 5). Ruta inline por pedido del usuario; commit registrado abajo.
- [ ] 5 Fase 5 — código integrado (texto, voz, foto, home y refresco de estadísticas); `flutter analyze --no-pub --no-fatal-infos` 0 errores/0 warnings (135 infos), `flutter test --no-pub` 12/12 y APK debug compilado. Pendiente prueba manual Android (no hay dispositivo conectado) y Firebase Console. El cambio supera la heurística de 400 líneas porque reemplaza el sheet completo según el plan. El guardado ahora espera a Firestore para evitar falsos éxitos y refrescos prematuros. Ruta inline por pedido del usuario; commit registrado abajo.
- [ ] 6 Fase 6 — accesos directos implementados; `flutter analyze --no-pub --no-fatal-infos` 0 errores/0 warnings (136 infos), `flutter test --no-pub` 12/12, APK debug compilado. Pruebas de pulsación y arranque desde Android pendientes: no hay dispositivo conectado. Ruta inline por pedido del usuario; commit registrado abajo.
- [ ] 7 Fase 7 — dona, tendencia de 6 meses y ritmo del presupuesto implementados; `flutter analyze --no-pub --no-fatal-infos` 0 errores/0 warnings (132 infos), `flutter test --no-pub` 12/12 y APK debug compilado. Revisar gráficas visualmente en Android queda pendiente por falta de dispositivo. Ruta inline por pedido del usuario; commit registrado abajo.
- [ ] 8 Fase 8 — fuente Plus Jakarta Sans, `AppCard`, balance animado y botón `+` destacados; sin `withOpacity` en `lib`. `flutter analyze --no-pub --no-fatal-infos` 0 errores/0 warnings, 80 infos (9 `deprecated_member_use`, base 69); `flutter test --no-pub` 12/12, APK debug compilado. Revisión visual en Android pendiente. Ruta inline por pedido del usuario; commit registrado abajo.
- [ ] 9 Fase 9 — `ARCHITECTURE.md` actualizado y comprobaciones finales: `flutter analyze --no-pub --no-fatal-infos` 0 errores/0 warnings (80 infos, 9 deprecaciones), `flutter test --no-pub` 12/12, `flutter build apk --debug --no-pub` OK, `git diff --check` OK. Falta validación manual Android de fases 2, 5, 6 y 7; `flutter devices` solo muestra Linux y Chrome. Ruta inline por pedido del usuario; commit de documentación registrado abajo.

## Evidencia de commits de esta continuación
- Fase 2: `2bd86b5`.
- Fase 3: `e23ba1e`.
- Fase 4: `5739a08`.
- Fase 5: `7a4f8b4`.
- Fase 6: `7bf27f6`.
- Fase 7: `f3c1eaa`.
- Fase 8: `149a339`.
- Fase 9 (documentación y verificaciones automáticas): `ed16990`.

## Próximo paso
- Cambio aceptado por el usuario y completado localmente: aclarar entrada inteligente, quitar cámara del formulario, evitar visto sobre iconos y retirar ambas encuestas. Commits `3742ecb` y `a9e32a4`; 47 líneas añadidas y 1014 eliminadas, principalmente archivos de encuestas retirados. Se conserva sin incorporar el cambio de `firebase.json` generado por FlutterFire. TDD off (configuración previa); runner `flutter test --no-pub`. Engram sigue sin estar disponible.
- Usuario: completar AI Logic, SHA-256 debug, registro de App Check con Play Integrity y alta del token debug en Firebase Console; no activar enforcement de Firestore/Auth. No guardar el token en el repositorio.
- Con un Android disponible, probar chat de IA y los criterios manuales de texto, voz, foto, estadísticas, gráficos y accesos directos del plan.
- Engram y `gentle-ai` no están disponibles aquí: la copia de recuperación y la evaluación RDD quedan pendientes; no se ejecutó revisión nativa.
