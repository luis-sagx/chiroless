# Firma release para Android

Objetivo: generar un APK release de Chiroless firmado con una clave privada de distribución estable.

Problema: `android/app/build.gradle.kts` firma actualmente `release` con la clave debug. Play Integrity necesita que la instalación pueda validarse contra el certificado de firma configurado para la app Android.

Alcance autorizado: crear una clave de firma local, ignorada por Git; configurar Gradle para usarla; compilar y comprobar el APK release. No incluye cambios en Firebase Console, publicación ni envío del APK.

Restricciones: no incluir contraseñas ni el keystore en Git o en la salida; conservar el identificador `com.example.financial_control`; registrar que las instalaciones firmadas previamente con debug deben reinstalarse para adoptar el nuevo certificado.

TDD: deshabilitado para cambios de configuración según `odd/tasks/claridad-financiera.md`. Runner registrado: `flutter test --no-pub`; no ejecutar pruebas automatizadas sin solicitud explícita. Verificaciones aplicables: `flutter build apk --release --no-pub`, inspección del certificado APK, `git diff --check`.

Previsión: ~30 líneas añadidas/eliminadas; una tarea, por debajo del presupuesto de entrega de ~400 líneas. Estrategia de entrega: `ask-on-risk` (predeterminada). Rama: `feat/android-release-signing`, creada desde `main`.

## Tareas

- [x] T1 — Firmar el APK release con una clave local protegida y comprobar la salida. Alcance: añadir lectura de `android/keystore.properties` y configuración `signingConfigs.release` en `android/app/build.gradle.kts`; generar los archivos locales ignorados por Git; compilar y verificar el APK. Criterios: el build release termina correctamente; `apksigner` confirma la firma y muestra la huella SHA-256; keystore y propiedades no aparecen en Git. Ruta: inline; evidencia: un archivo Gradle explorado y artefactos locales ignorados. TDD off; runner `flutter test --no-pub`. Verificación: `flutter build apk --release --no-pub` correcto (67.9 MB); `apksigner verify --print-certs` correcto, SHA-256 `70b12b0707196e2a58ffa8c3481299f4be5cddb14a083221c3da340e9175825a`; `git diff --check` limpio; Git ignora `android/keystore.properties` y `android/app/chiroless-release.jks`.

## Progreso y evidencia

- Exploración: `main.dart` inicializa Firebase y App Check; Android release está firmado con `signingConfigs.debug`; `.gitignore` excluye `*.jks` y `keystore.properties`. El usuario autorizó configurar el firmado y generar el APK.
- `gentle-ai review mode status` no está disponible (`gentle-ai: command not found`); RDD no se ejecutará ni se inferirá un resultado.
- Espejo Engram: pendiente, no hay herramientas de memoria disponibles en esta sesión.
- Próximo paso: crear el commit de trabajo en esta rama y registrar su identidad aquí.
