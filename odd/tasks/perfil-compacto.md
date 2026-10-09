# Perfil compacto

- Objetivo: mejorar la lectura y el uso de la sección Perfil en Inicio.
- Problema: la cabecera centrada ocupa demasiado alto y algunas acciones no están en un lugar intuitivo; “Acerca de” no aporta valor en este flujo.
- Motivo: hacer más visible la identidad, facilitar encontrar acciones y separar ajustes financieros de los datos de cuenta.
- Alcance autorizado: cabecera compacta con nombre, correo y nivel; agrupación visual de opciones; quitar el acceso a “Acerca de” del perfil; mover la edición de saldo inicial a una opción independiente dentro de Perfil.
- Restricciones: conservar las acciones y destinos existentes; preservar la edición de monto y fecha del saldo inicial y sus datos guardados.
- Criterios de aceptación: identidad en una tarjeta horizontal de menor altura; opciones separadas por grupos comprensibles; no aparece “Acerca de” en el perfil; el resto de acciones sigue navegando a sus destinos actuales; saldo inicial se edita desde una pantalla propia accesible como opción “Saldo inicial” en Perfil y ya no aparece en “Editar perfil”.
- Rama: `feat/perfil-compacto` (desde `main`).
- Ruta P1: directa inline; la exploración localizó el flujo en `home_page.dart` y el cambio editado cabía en un único archivo.
- TDD efectivo: desactivado por instrucción de mayor prioridad que limita pruebas a una solicitud explícita de probar/verificar; runner registrado: `flutter test --no-pub`.
- Estrategia de entrega: `ask-on-risk`; la previsión acumulada es de aproximadamente 715 líneas modificadas contando P1 y P2. Se debe acordar una estrategia de cadena antes del siguiente commit.
- RDD: no disponible; `gentle-ai review mode status` falló porque el comando no está instalado.
- Espejo Engram: pendiente; no hay herramientas Engram disponibles en esta sesión.

## Tareas

- [x] P1 — Compactar y organizar la sección Perfil. Evidencia: cabecera horizontal de 56 px con nombre/correo truncados de forma segura y nivel; opciones agrupadas en Cuenta, Preferencias (Android), Ayuda y Legal; enlace a “Acerca de” retirado y destinos restantes conservados. `dart format` y `git diff --check` limpios. `flutter analyze --no-pub --no-fatal-infos lib/features/home/presentation/pages/home_page.dart` terminó sin errores ni avisos nuevos (5 sugerencias informativas preexistentes); el análisis general terminó sin errores (75 infos en el proyecto). No se ejecutaron pruebas. Revisión puntual del diff: sin hallazgos. Cambio: 298 líneas añadidas/eliminadas, bajo el presupuesto aproximado de 400. Ruta inline; trigger: la implementación se limita a la pantalla existente en un archivo.
- [ ] P2 — Mover el saldo inicial fuera de “Editar perfil”. Evidencia esperada: opción independiente “Saldo inicial” en Perfil; pantalla propia que conserva edición de monto, fecha y guardado; retirar esa sección del formulario de nombre/contraseña. Ruta delegada; trigger: implementación coordinada en 3 archivos no triviales (nueva pantalla, formulario actual y navegación desde Perfil). TDD off; runner registrado `flutter test --no-pub`; no ejecutar pruebas. Commit pendiente de estrategia de cadena por previsión acumulada superior a 400 líneas.

## Progreso y siguiente paso

- Diseño aprobado por el usuario: cabecera horizontal compacta, opciones agrupadas, quitar “Acerca de” y ofrecer “Saldo inicial” como opción independiente en Perfil.
- Espejo Engram pendiente por falta de herramientas.
- P1 completada en el commit de trabajo `a13fddb` (`feat(profile): compact and organize profile screen`).
- P2 implementada en el árbol de trabajo; `dart format --output=none --set-exit-if-changed` y `git diff --check` pasan. El análisis estático de los 3 archivos terminó sin errores ni sugerencias nuevas (6 infos preexistentes en dos archivos); no se ejecutaron pruebas. Espejo Engram pendiente por falta de herramienta.
- P2 espera el commit de trabajo: la previsión acumulada supera 400 líneas y `ask-on-risk` requiere elegir `stacked-to-main` o `feature-branch-chain` antes del siguiente commit.
