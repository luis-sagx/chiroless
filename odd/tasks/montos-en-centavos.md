# montos-en-centavos

Objetivo: interpretar correctamente unidades de dólares y centavos en montos dictados o escritos.

Problema y motivo: el parser local trata el primer número como dólares aunque el texto diga “centavos”; “50 centavos” puede convertirse en 50 dólares. La extracción con IA tampoco tiene una regla explícita de conversión.

Alcance autorizado: convertir frases simples y mixtas con dólares/centavos a un monto decimal; alinear la instrucción de extracción IA; incluir pruebas automatizadas de las expresiones autorizadas. “0.5” sigue siendo 0,50. Se conserva el borrador para revisión antes de guardar.

Restricciones: no cambiar el reconocimiento de voz ni el flujo de guardado; evitar interpretar como USD las unidades de otras monedas; preservar el comportamiento existente cuando no se mencionan unidades.

Aceptación: “50 centavos” → 0.50; “50 dólares” → 50; “1 dólar con 50 centavos” → 1.50; “0.5” → 0.50. La indicación para IA expresa las mismas reglas y no cambia el tratamiento de imágenes.

TDD efectivo: deshabilitado según configuración previa registrada en `odd/tasks/claridad-financiera.md` y `odd/tasks/registro-inteligente.md`. Runner del proyecto: `flutter test --no-pub`.

Pronóstico inicial: aproximadamente 100 líneas añadidas y modificadas, sin archivos generados. Estrategia de entrega: ask-on-risk; no se planea crear PR en esta solicitud.

RDD: el ejecutable `gentle-ai` no está disponible en este entorno; evaluación y espejo Engram pendientes. Mantener política ordinaria del repositorio y no atribuir aprobación nativa.

## Tareas

- [x] C1 Normalizar unidades monetarias en el parser local y en la extracción IA; agregar pruebas de parser para expresiones simples, mixtas y decimales. Ruta: delegada (writer trigger: la implementación abarca parser, servicio IA y pruebas, tres archivos no triviales). TDD efectivo: off; runner registrado: `flutter test --no-pub`. La regla para IA se agregó solo a `fromText`, sin cambiar el flujo de imágenes. Verificación del padre: `flutter test --no-pub` pasó (53 pruebas); `flutter analyze --no-pub --no-fatal-infos` salió correctamente (82 avisos informativos, sin errores ni advertencias); `git diff --check` limpio. Prueba focalizada reportada por el writer: 16 pruebas pasaron. Commit de implementación pendiente.

## Progreso y evidencia

- Diseño breve aprobado por el usuario el 2026-10-08.
- El parser convierte centavos y montos mixtos, conserva decimales sin unidad y deja sin monto unidades extranjeras reconocidas. La extracción IA aplica las mismas reglas para texto.

## Próximo paso

- Registrar el commit de implementación en esta tarea y completar el commit local.

## Espejo Engram

- Pendiente: las herramientas de memoria/Engram no están disponibles en este entorno.
