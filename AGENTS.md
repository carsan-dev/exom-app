# exom-app: instrucciones para agentes

Este repo forma parte del workspace EXOM. El protocolo común es `../AGENTS.md` y debes leerlo antes de cambiar nada (Codex no lo carga por sí solo desde aquí).

## Repo

- Stack: Flutter 3.41.5 (canal stable), Dart; Android e iOS.
- Rama base: `develop` (PR a `develop`; `main` es la release).

## Comandos

- `flutter pub get --enforce-lockfile`, `flutter analyze`, `flutter test`, `node --test scripts/verify-release.test.mjs`.
- Dispositivo Android en desarrollo: `scripts\run-android-dev.cmd` (ver `README.md`).
- Android no acredita por sí solo un cambio específico de iOS.

## CI y publicación

- CI (`.github/workflows/ci.yml`): los cuatro comandos anteriores, en ese orden.
- `Mobile Release` (`mobile-release.yml`) se dispara al subir un tag `v*` o a mano, y publica en Play Store. `Publish Mobile Release Metadata` (manual) cambia la configuración móvil de la API. Nunca subas tags ni lances estos workflows, ni hagas push, sin que el propietario lo pida.
- Versión y notas de release viven en `pubspec.yaml` y `release-notes/`; no los toques sin petición.

## Arnés (resumen de `../AGENTS.md`)

- Salida de tests/analyze a un log fuera del repo; lee solo el resumen (Flutter `All tests passed!|Some tests failed|\[E\]`).
- Commits convencionales con ámbito y en español, sin atribución de IA ni `Co-Authored-By`; sin commit, push, merge ni tag sin petición del propietario.
- Worktrees en `EXOM/exom-app-worktrees/<nombre>`, nunca en `/tmp`, con su propio `.codegraph/` y `flutter pub get`.
- Sin gentle-ai ni `.atl/skill-registry.md`. Archivos nuevos en LF (`tr -cd '\r' < fichero | wc -c` = 0).
