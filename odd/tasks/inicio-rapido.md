# Inicio rápido

Objetivo: hacer que Inicio y el registro de ingresos/gastos estén disponibles cuanto antes; mostrar la marca durante una carga real y una bienvenida breve solo en el primer inicio sin sesión.
Problema: el splash espera 700 ms fijos; `IndexedStack` monta Estadísticas y Logros al entrar en Inicio; Estadísticas repite lecturas de movimientos del mismo mes.
Alcance autorizado: mejoras locales del arranque, carga de pestañas y consultas de Estadísticas solicitadas por el usuario. No incluye operaciones remotas ni despliegue de índices.
Interpretación de «primera vez»: primer arranque de esta instalación sin sesión, recordado localmente. En arranques posteriores se muestra splash mientras se resuelve una carga real; no se impone espera a usuarios con sesión lista.
Restricciones: el botón + y el guardado de gastos/ingresos siguen independientes de la carga de perfil y pestañas secundarias; conservar resultados y estados de error; evitar consultas históricas sin límite y nuevos índices de Firestore.
Rama: `feat/inicio-rapido`, creada desde `feat/claridad-financiera`. TDD efectivo: off, fuente `odd/tasks/claridad-financiera.md`; runner `flutter test --no-pub`. Checks por tarea: `flutter test --no-pub`, `flutter analyze --no-pub --no-fatal-infos`, `flutter build apk --debug --no-pub`, `git diff --check`.
Engram: mirror `odd/inicio-rapido/tasks` pendiente (herramientas no disponibles). RDD: deshabilitado/no gestionado (`gentle-ai` no disponible). Entrega: `single-pr` como estrategia de trabajo local; no hay PR autorizado. Pronóstico: 450–700 líneas modificadas; revisar reglas de tamaño antes de cualquier PR.

## Tareas

- [ ] P1 Arranque: resolver sesión desde el inicio, quitar espera fija de 700 ms, mostrar bienvenida breve solo en primer arranque sin sesión y conservar splash mientras la preparación real no termina; reducir pantalla blanca nativa si los recursos actuales lo permiten. Ruta delegada: mapeo de 4+ archivos y escritura de 2+ archivos no triviales. Criterio: usuario con sesión lista navega en cuanto se resuelve; primer usuario sin sesión ve bienvenida; arranque lento conserva pantalla de marca. Checks: prueba de rutas/estado y checks generales.
- [ ] P2 Inicio: montar Estadísticas y Logros solo al abrirlos y conservar su estado al cambiar pestañas; acceso + no espera ninguna carga secundaria. Ruta delegada por 2+ archivos no triviales si aplica; si queda en un cambio mecánico de un archivo, inline. Criterio: no se disparan cargas secundarias al abrir Inicio; + sigue disponible. Checks: prueba de montaje perezoso y checks generales.
- [ ] P3 Estadísticas: reutilizar datos del mes actual entre resumen, categorías, ritmo y tendencia; evitar solicitudes duplicadas al cambiar rango y conservar resultado correcto/errores, sin índices nuevos. Ruta delegada por 2+ archivos no triviales. Criterio: menos consultas para el rango inicial que las ~17 actuales, con totales y meses correctos. Checks: pruebas de agregación/estado y checks generales.

## Progreso y evidencia

- Exploración: `main.dart` inicializa configuración/Firebase/App Check antes de `runApp`; `splash_screen.dart` espera 700 ms antes de consultar usuario; Inicio monta pestañas ocultas; Estadísticas hace unas 17 consultas con seis meses, contando lecturas repetidas del mes actual. No hay Android conectado para medir latencia real; recuentos son inferidos del código.
- Próximo paso: implementar P1 y verificar en tests/análisis/compilación. RDD permanece deshabilitado. No se ha iniciado PR.
