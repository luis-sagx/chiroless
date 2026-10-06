# Inicio rápido

Objetivo: hacer que Inicio y el registro de ingresos/gastos estén disponibles cuanto antes; mostrar la marca durante una carga real y una bienvenida breve solo en el primer inicio sin sesión.
Problema: el splash espera 700 ms fijos; `IndexedStack` monta Estadísticas y Logros al entrar en Inicio; Estadísticas repite lecturas de movimientos del mismo mes.
Alcance autorizado: mejoras locales del arranque, carga de pestañas y consultas de Estadísticas solicitadas por el usuario. No incluye operaciones remotas ni despliegue de índices.
Interpretación de «primera vez»: primer arranque de esta instalación sin sesión, recordado localmente. En arranques posteriores se muestra splash mientras se resuelve una carga real; no se impone espera a usuarios con sesión lista.
Restricciones: el botón + y el guardado de gastos/ingresos siguen independientes de la carga de perfil y pestañas secundarias; conservar resultados y estados de error; evitar consultas históricas sin límite y nuevos índices de Firestore.
Rama: `feat/inicio-rapido`, creada desde `feat/claridad-financiera`. TDD efectivo: off, fuente `odd/tasks/claridad-financiera.md`; runner `flutter test --no-pub`. Checks por tarea: `flutter test --no-pub`, `flutter analyze --no-pub --no-fatal-infos`, `flutter build apk --debug --no-pub`, `git diff --check`.
Engram: mirror `odd/inicio-rapido/tasks` pendiente (herramientas no disponibles). RDD: deshabilitado/no gestionado (`gentle-ai` no disponible). Entrega: `single-pr` como estrategia de trabajo local; no hay PR autorizado. Pronóstico: 450–700 líneas modificadas; revisar reglas de tamaño antes de cualquier PR.

## Tareas

- [x] P1 Arranque: sesión resuelta al iniciar con el primer estado de Firebase Auth; usuario autenticado omite preferencias y esperas fijas; primera instalación sin sesión ve 700 ms de bienvenida, guardada localmente; splash queda visible mientras la sesión aún se resuelve. Fondo nativo Android usa el icono existente. Ruta delegada: mapeo de 4+ archivos y escritura de 2+ archivos no triviales. Commit `df7e55f` (251 líneas modificadas, incluye lock generado). `flutter test --no-pub`: 43 aprobadas; APK debug compilado; `git diff --check`: limpio. Medición y revisión visual Android pendientes por falta de dispositivo. Análisis completo posterior devolvió código 1 por 72 infos preexistentes, sin errores ni warnings.
- [x] P2 Inicio: Estadísticas y Logros se montan solo al abrirlos y mantienen estado al cambiar pestañas; acceso + sigue independiente. Ruta delegada por 3 archivos no triviales. Commit `2b5632c` (123 líneas modificadas). `flutter test --no-pub`: 44 aprobadas, incluida prueba de montaje; APK debug compilado; `git diff --check`: limpio. `flutter analyze --no-pub --no-fatal-infos`: código 1 por 72 infos preexistentes, sin errores ni warnings.
- [ ] P3 Estadísticas: reutilizar datos del mes actual entre resumen, categorías, ritmo y tendencia; evitar solicitudes duplicadas al cambiar rango y conservar resultado correcto/errores, sin índices nuevos. Ruta delegada por 2+ archivos no triviales. Criterio: menos consultas para el rango inicial que las ~17 actuales, con totales y meses correctos. Checks: pruebas de agregación/estado y checks generales.

## Progreso y evidencia

- Exploración: `main.dart` inicializa configuración/Firebase/App Check antes de `runApp`; `splash_screen.dart` espera 700 ms antes de consultar usuario; Inicio monta pestañas ocultas; Estadísticas hace unas 17 consultas con seis meses, contando lecturas repetidas del mes actual. No hay Android conectado para medir latencia real; recuentos son inferidos del código.
- Próximo paso: implementar P3. RDD permanece deshabilitado. No se ha iniciado PR.
