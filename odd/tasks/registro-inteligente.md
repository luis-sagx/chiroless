# registro-inteligente

Objetivo: registro de ingresos/gastos fácil (texto libre, voz, foto, atajos), gráficas claras, estilo con más vida.
Fuente de verdad: `PLAN_REGISTRO_INTELIGENTE.md` (fases 0–9). Rama: `feat/registro-inteligente`.
TDD: off salvo Fase 3 (plan lo exige). Runner: `flutter test`. Checks por fase: `flutter analyze` (0 err/0 warn), `flutter test`, desde Fase 2 `flutter build apk --debug`.
Autorizado: Fase 0 y Fase 1 (D1: no está en Play Store, solo local; a futuro sí). Fase 2+ requiere ir confirmando.
Delivery: ask-on-risk. Push/PR/merge: decisión del usuario. Commits sin coautor (pedido del usuario).

## Tareas
- [x] 0 Fase 0 — commit 7aac48e
- [x] 1 Fase 1 — commit eb3de6a (ruta: inline por pedido del usuario; analyze 0 err/0 warn, test ok)
- [ ] 2 Fase 2 — firebase_ai + App Check (incluye pasos HUMANO)
- [ ] 3 Fase 3 — parser local (TDD)
- [ ] 4 Fase 4 — extracción IA texto/foto
- [ ] 5 Fase 5 — QuickAddSheet inteligente
- [ ] 6 Fase 6 — App shortcuts
- [ ] 7 Fase 7 — gráficas
- [ ] 8 Fase 8 — estilo
- [ ] 9 Fase 9 — verificación final + docs
