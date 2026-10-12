# REST-APP-VERSION-01 — versión 1.2.3 y notas de distribución

> Copia saneada para entrega: ubicaciones normalizadas; resultados, fechas y hashes conservan su significado histórico y corresponden al snapshot privado original, no a esta copia. WORKSPACE_ROOT identifica la coordinación; SDK_ROOT el SDK instalado; RUNTIME_ROOT las herramientas locales; TEST_ARTIFACT_ROOT los recursos privados retenidos, no publicados.


Fecha: 2026-10-09, Europe/Madrid. Alcance autorizado: incorporar la versión que modificó el usuario y completar las dos notas de distribución. Sin cambios de producto, dependencias, configuración de distribución ni publicación.

## Identidad y conservación

- Raíz de coordinación: `${WORKSPACE_ROOT}/`, sin Git utilizable. Snapshot leído: AGENTS SHA256 `f21dc8259e9ff8b7a02122efd9b1651a4a22859081c6871722b099c8476a38db`; plan `9332524f9d699412a19a9154a7a1db426c7d2688770d4cb6b5978db9d9e18a8c`; seguimiento `60119afe6b6fde74746f739526f414d6a7b906edccb2394ea573fc0c655831b9`. Son hashes de archivos, no commits.
- App: `${WORKSPACE_ROOT}/exom-app`; HEAD `419e133b853934e5cde1d1d25446715dc535d53f`; rama `fix/scoped-training-discard`; upstream `origin/fix/scoped-training-discard`. Estado inicial: solamente `M pubspec.yaml`.
- `pubspec.yaml` conserva exactamente los bytes del usuario: `version: 1.2.3+1`, SHA256 `9c4f8afdea3497121a9e8df979a062491aba94c4ac07aa820fd210762480ac6a`, antes/después. No se ajustó el build number.
- `pubspec.lock` intacto: SHA256 `8ce850ec0cb0d5e22540a418819ab221030e9bdf393e1ca50330e3b6466c1511`, igual en original y worktree tras resolución offline.
- APK previo del checkout original intacto, 172772119 bytes, SHA256 `b1e89b6a2bbb8b63c8eec707c581f24d87249c4800f1800d0a5d61835cb69cfb`. No acredita la nueva versión y no fue sobrescrito ni copiado.

## Notas y consumidores

Se añadió una sola viñeta por idioma: revisión publicada del recap con resumen del coach, cambios y objetivos de la próxima semana. Evidencia: `RecapPublishedReviewCard` solo renderiza `publishedCoachSummary`, `publishedChanges` y `publishedNextWeekGoals`, condicionado por `hasPublishedReview`; el detalle incorpora esa tarjeta. Modelo/tests conservan separación respecto de borradores y notas privadas. Rango relevante: `db72c7f` (1.2.2) hasta HEAD, incluida implementación `afb7230` y regresiones posteriores. Las cuatro correcciones de entrenamiento previas siguen presentes y se conservan; no se añadieron Dashboard/P6/tareas internas ni afirmaciones de despliegue.

| Archivo | SHA256 anterior | SHA256 final | Caracteres / bytes UTF-8 |
| --- | --- | --- | --- |
| `distribution/whatsnew/whatsnew-en-US` | `34160074d2458c227d09f03702759f30d5ddba4f94ef49227110298665544d8b` | `52ba2d539bda3aa697034155281970cfe3605b6d495a78f7050e28404219e46f` | 398 / 398 |
| `distribution/whatsnew/whatsnew-es-ES` | `c8cc975b1bfb0f6447d08eaf934c5b80876f0951c4075801dc5bdf6716521aad` | `06e5fdeee641b111c42e62c47e1725f0ee4a5bde77764d96a6b4539252259237` | 470 / 475 |

Ambos: cinco viñetas, UTF-8 sin BOM, LF, un único salto final y sin espacios finales. Check local conservador de longitud <=500 caracteres PASS; no se atribuye a un validador remoto. No existe validación local de longitud en `scripts/verify-release.mjs`: valida identidad de release y consulta GitHub al ejecutarse; no se ejecutó.

Android `android/app/build.gradle.kts` usa `flutter.versionName` / `flutter.versionCode`; iOS Runner y widget usan `FLUTTER_BUILD_NAME` / `FLUTTER_BUILD_NUMBER`. No se detectó divergencia que requiera editar consumidores. El workflow móvil lee el nombre de `pubspec.yaml` y calcula un build incremental desde `MOBILE_BUILD_NUMBER` o override validado; no fue activado ni se consultaron variables remotas.

## Verificación observada

Runner instalado: `${RUNTIME_ROOT}/flutter/bin/cache/dart-sdk/bin/dart.exe ${RUNTIME_ROOT}/flutter/bin/cache/flutter_tools.snapshot`; SDK local Flutter 3.41.5 / Dart 3.11.3. Windows, CI=true. Cada resultado corresponde a los bytes actuales de versión/notas; producto/tests permanecen HEAD.

| Criterio / comando | Resultado | Evidencia reproducible |
| --- | --- | --- |
| RED para metadatos/notas | NOT_APPLICABLE | No lógica nueva ni bug demostrado con RED ejecutable; prueba estructural de bytes/consumidores |
| Runner `analyze --no-pub`, checkout original | PASS | Sesión 5797, exit0, 0 issues, 42.7s |
| Runner `test --no-pub --reporter compact`, checkout original | PASS | Sesión 41534, exit0, 544 tests, 0 fallos, 1:51 |
| Runner `pub get --offline`, worktree propio | PASS | Sesión16944, exit0; caché instalada, mismo lock SHA; no descarga de dependencias autorizada |
| Gradle8.14 `--offline --no-daemon -Ptarget=docs/evidence/rest-t3c-app-20261008/recap_ui_harness.dart -Ptarget-platform=android-arm,android-arm64,android-x64 -Pbuild-mode=debug assembleDebug` | PASS | Sesión42312, exit0, BUILD SUCCESSFUL, 2m21s, 632 tareas; log preservado en worktree |
| `aapt.exe dump badging` del nuevo APK | PASS | versionName=1.2.3, versionCode=1, minSdk24, targetSdk36 |
| `git diff --check`, original/worktree; notas y recibo nuevos leídos | PASS | Sin errores; archivos nuevos comprobados también por bytes, EOF y espacios finales |
| Compilación nativa iOS | NOT_RUN | Windows sin macOS/Xcode; consumidores inspeccionados no equivalen a compilación |
| Build main/release, instalación y smoke en dispositivo, providers reales | NOT_RUN | Solo compilación sintética autorizada, no arranque ni publicación |

Incidencias del entorno, no PASS inventado: `flutter.bat build apk --help` no produjo salida y fue cancelado; runner inicial bajo sandbox denegó acceso al lock del SDK, y la ejecución local con permiso de caché terminó correctamente. Primer intento `gradlew.bat` NOT_RUN por wrapper generado ausente en worktree nuevo; se usó distribución Gradle8.14 ya instalada. Build emitió advertencias de deprecación Kotlin/Gradle, no fueron corregidas ni ocultadas.

## Aislamiento Android y recuperación

Worktree detached nuevo: `${WORKSPACE_ROOT}/.odd-worktrees/exom-app-version-123-20261009`, desde HEAD419e133. Comprobación previa por nombres Git tracked sin archivos de credenciales/signing/Firebase. Solo se copiaron los bytes de pubspec y las dos notas. No se reutilizó índice CodeGraph. En original existe `android/app/key.properties`, cuyo contenido no se abrió; por eso NO se compiló allí. El worktree no contiene ese archivo ni credenciales copiadas.

Se creó únicamente configuración Firebase ficticia ignorada `android/app/google-services.json` (SHA256 `cc1d9ea70a68ea159d0d310edfbc1d5eb2a6336e49e63f6d6327ad18e35c18f5`): proyecto `exom-version-123-test-only`, número `123456789012`, bucket `.invalid`, app ID ficticio, clave literal `synthetic-test-only-not-a-real-key`, package `com.exommethod.exom`, oauth vacío. `android/local.properties` propio contiene rutas de SDK instalados y versión 1.2.3/build1; JAVA_HOME apunta al JBR instalado. No dotenv requerido. No se instalaron SDK/dependencias ni se ejecutó flutter clean.

Entrypoint existente `docs/evidence/rest-t3c-app-20261008/recap_ui_harness.dart`, SHA256 `e7741a9d3c854c960c86dfa45ff346ad0678b692ca75f9032550f6c2e84ef1b9`, no importa main/bootstrap/Firebase/HTTP. Se enlazan plugins instalados sin iniciar providers. El APK acredita compilación del harness y metadatos Android, NO equivalencia completa con main ni configuración de producción ni prueba visual en dispositivo.

Nuevo APK preservado en worktree `build/app/outputs/flutter-apk/app-debug.apk`: 160666411 bytes, SHA256 `6da075c3f155403805f2900c135bc92322fc41416908233f1aead0d86ea74a13`, versionName1.2.3/code1. Log `version-123-build.log`; manifiesto local no publicable en coordinación `docs/evidence/p5-app-version-123-build-20261009/build-manifest.json`. Ambos APK permanecen en sus ubicaciones separadas; no se generó backup redundante.

Superficie stageable propia: las dos notas y este recibo; `pubspec.yaml` pertenece al usuario y debe incorporarse preservando esos bytes. Sin stage/commit/push/tags/releases/workflow/Codemagic, memoria ni fuentes adicionales. Seguimiento/cierre y acciones externas pertenecen al coordinador. Este recibo registra validación local, no DONE global ni distribución publicada.
