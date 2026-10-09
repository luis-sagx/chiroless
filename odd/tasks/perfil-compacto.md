# Perfil compacto

- Objetivo: mejorar la lectura y el uso de la sección Perfil en Inicio.
- Problema: la cabecera centrada ocupa demasiado alto y las acciones aparecen en una lista larga sin agrupación; “Acerca de” no aporta valor en este flujo.
- Motivo: hacer más visible la identidad y facilitar encontrar acciones de cuenta, ayuda y documentos.
- Alcance autorizado: cabecera compacta con nombre, correo y nivel; agrupación visual de opciones; quitar el acceso a “Acerca de” del perfil.
- Restricciones: conservar las acciones existentes y sus destinos; no cambiar datos ni lógica de cuenta.
- Criterios de aceptación: identidad en una tarjeta horizontal de menor altura; opciones separadas por grupos comprensibles; no aparece “Acerca de” en el perfil; el resto de acciones sigue navegando a sus destinos actuales.
- Rama: `feat/perfil-compacto` (desde `main`).
- Ruta: directa inline; la exploración localizó el flujo en `home_page.dart` y el cambio editado cabe en un único archivo.
- TDD efectivo: desactivado por instrucción de mayor prioridad que limita pruebas a una solicitud explícita de probar/verificar; runner registrado: `flutter test --no-pub`.
- Estrategia de entrega: `ask-on-risk` (predicción: menos de 400 líneas modificadas).
- RDD: no disponible; `gentle-ai review mode status` falló porque el comando no está instalado.
- Espejo Engram: pendiente; no hay herramientas Engram disponibles en esta sesión.

## Tareas

- [x] P1 — Compactar y organizar la sección Perfil. Evidencia: cabecera horizontal de 56 px con nombre/correo truncados de forma segura y nivel; opciones agrupadas en Cuenta, Preferencias (Android), Ayuda y Legal; enlace a “Acerca de” retirado y destinos restantes conservados. `dart format` y `git diff --check` limpios. `flutter analyze --no-pub --no-fatal-infos lib/features/home/presentation/pages/home_page.dart` terminó sin errores ni avisos nuevos (5 sugerencias informativas preexistentes); el análisis general terminó sin errores (75 infos en el proyecto). No se ejecutaron pruebas. Revisión puntual del diff: sin hallazgos. Cambio: 298 líneas añadidas/eliminadas, bajo el presupuesto aproximado de 400. Ruta inline; trigger: la implementación se limita a la pantalla existente en un archivo.

## Progreso y siguiente paso

- Diseño aprobado por el usuario: cabecera horizontal compacta, opciones agrupadas y quitar “Acerca de”.
- Espejo Engram pendiente por falta de herramientas.
- P1 completada en el commit de trabajo `a13fddb` (`feat(profile): compact and organize profile screen`).
- Siguiente paso: ninguno para la implementación; el espejo Engram queda pendiente por falta de herramienta.
