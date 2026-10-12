# REST-T3D-APP-01 — signed-out recap detail terminates safely

> Copia saneada para entrega: ubicaciones normalizadas; resultados, fechas y hashes conservan su significado histórico y corresponden al snapshot privado original, no a esta copia. WORKSPACE_ROOT identifica la coordinación; SDK_ROOT el SDK instalado; RUNTIME_ROOT las herramientas locales; TEST_ARTIFACT_ROOT los recursos privados retenidos, no publicados.


2026-10-08 UTC. **Source bug fixed; independent real-Bloc widget smoke/focused20/full544/analyze0 and isolated Android compilation PASS.** Installed-device/iOS checks NOT_RUN; no automatic logout-routing or live-service claim. New candidate review/commit remain pending; REST-T3D/P5 are not closed.

## Scope and baseline

- Root: `${WORKSPACE_ROOT}/` (coordination non-Git, parent-provided); App checkout `exom-app` verified clean before edits.
- HEAD: `808ea370257bcd01f7cfbd4ee8a05d53bf0b2d14`, branch `fix/scoped-training-discard`, upstream `origin/fix/scoped-training-discard`, merge-base `db72c7feee2c3ba91bc71068a7918903179ca78d`; no fetch, staging or commit.
- Parent references only: API `2860703` with original probe; Admin `6f5080b` clean. Neither repository was modified or run.
- Read CURRENT task and P5-02: publication visible in App without private notes. Scope is only the missing-session detail outcome; no list/training/auth-router redesign or offline-auth fallback.
- Strict TDD: explicit parent test-first choice and exact runner below. Parent-verified Flutter 3.41.5 / Dart 3.11.3 reused; version command not rerun. Tests use owned synthetic repositories/session providers, no live API/Firebase/DB or emulator.
- Injected cognitive-doc-design and work-unit-commits skills read completely. Read-only CodeGraph exploration preceded source inspection; stale-index source was reread directly, no index mutation.

Coordination document snapshot (unchanged by writer, SHA256 observed at `2026-10-08T12:15:01Z` or later; not a Git revision):

| Document | SHA256 |
| --- | --- |
| `AGENTS.md` | `f21dc8259e9ff8b7a02122efd9b1651a4a22859081c6871722b099c8476a38db` |
| `docs/plans/progreso-clientes-plan.md` | `9332524f9d699412a19a9154a7a1db426c7d2688770d4cb6b5978db9d9e18a8c` |
| `odd/tasks/progress-remaining-phases.md` | `efdd706e22efd7561814cc848cff0cbf8cd3e8b06b22b0f5494d168e45c3da9e` |

## Independent causal reproduction and correction

Actual baseline `_onDetailRequested` increments epoch, captures null `LocalStorage.sessionStamp`, emits `RecapDetailLoading`, then returns without a request or terminal state. `recap_detail_page.dart:68–70` renders a skeleton for that state. The baseline signed-out test asserted only no detail request. This independently confirmed source bug is **not reconstructed native finding text**: full `R3-signed-out-loading` native advisory remains unavailable; consumed authorities were neither queried nor reopened.

Minimal correction emits existing non-data `RecapDetailError('Inicia sesión para ver el recap.')` before returning. The existing detail error renderer handles it without a new UI state. Previously loaded recap content is replaced, not retained as an error fallback. Epoch/session capture, transport zone and late response/feedback guards are unchanged.

Regressions assert terminal error and no requests for a fresh signed-out detail and after previously loaded A, including refusing feedback from A. Triangulation: pending A, signed-out request B, restored same session stamp, then late A completion still cannot replace the terminal error. Existing account/generation/logout, newer B, late errors, feedback and legacy form/list tests remain intact.

## Observed verification

All commands ran foreground from `exom-app`; no known environmental failures. UTC windows are bounded by surrounding tool timestamps, not invented exact command start times.

| Exact command | UTC window / stage | Result |
| --- | --- | --- |
| `${RUNTIME_ROOT}/flutter/bin/flutter test --no-pub test/features/recap/presentation/bloc/recap_bloc_test.dart` | 12:11:54–12:12:12 RED, source unchanged | FAIL exit1: 12 PASS / 2 intended state failures, expected `RecapDetailError`, actual `RecapDetailLoading`; request assertions passed |
| `${RUNTIME_ROOT}/flutter/bin/flutter test --no-pub test/features/recap/presentation/bloc/recap_bloc_test.dart` | 12:12:12–12:12:50 initial GREEN | PASS exit0: 14 tests |
| `${RUNTIME_ROOT}/flutter/bin/flutter test --no-pub test/features/recap/presentation/bloc/recap_bloc_test.dart` | 12:12:50–12:14:27 final triangulation | PASS exit0: 15 tests |
| `${RUNTIME_ROOT}/flutter/bin/flutter test --no-pub` | 12:12:50–12:14:27 | PASS exit0: 542 tests; Hive adapter-override warning emitted, not repaired |
| `${RUNTIME_ROOT}/flutter/bin/flutter analyze --no-pub` | 12:14:27–12:15:01 | PASS exit0: 0 issues |
| `git diff --check` | After receipt creation, 2026-10-08 UTC | PASS exit0: no whitespace diagnostics on tracked changes; new README also inspected separately |

RED/GREEN/focused/analyzer output is preserved in writer tool results. Full suite tool-temp log: `${RUNTIME_ROOT}/AppData/Local/Temp/pi-bash-067a37fc17471061.log` (**LOCAL_ONLY**, not clone-recoverable). No source/test edits occurred after the final focused/full/analyze runs. No formatter, build, installation, network-changing action, native review or cleanup ran.

## Source and test identity / rollback

SHA256 of exact bytes; baseline from clean HEAD, RED recorded before source fix, final recorded after checks at `2026-10-08T12:15:01Z`:

| App-relative path | Baseline SHA256 | Final SHA256 |
| --- | --- | --- |
| `lib/features/recap/presentation/bloc/recap_bloc.dart` | `e2a1abb9ca10c20142aabc7006f90e748492430ac8b7c9ab571416e5f2e8df92` | `ba2ee61c27bdab4860aae70f333aee857f271558a786f9e3c48b4b0b97d69656` |
| `test/features/recap/presentation/bloc/recap_bloc_test.dart` | `8835ad21ea1c364fdcedd8cd61cc4beecf06729d442c21d82b208c1c44f2468e` | `10bef34946efcc175316ec225bf4fa904a4256890ec5a26edd46c7da66d6e19f` |

RED test SHA256: `862e925edf60248931ce42e3b94faaab61e7d93c2c48d4fbc750a8197bad19e3`. Source remained identical to baseline during RED. Rollback boundary is exactly the two Dart paths above plus this new `docs/evidence/rest-t3d-app-20261008/README.md`; reverse only this unit's hunks after preserving the candidate. Do not roll back unrelated work or remove ignored APK/resources. Uncommitted candidate remains in the working tree for parent checkpoint/review/commit disposition; HEAD alone does not identify it.

## Bounded detail-page widget smoke — 2026-10-08 UTC

**PASS: real detail page + real Bloc + synthetic repository/session provider.** No renderer-only error fixture, bootstrap, Firebase, real API, device/emulator or installation. Only the existing page test and this receipt were edited in this continuation; earlier Bloc/source work was preserved byte-for-byte. Read CURRENT task projection before edits. Injected cognitive-doc-design skill read completely; no structural discovery or CodeGraph/index mutation was needed for the exact supplied files.

Two additional widget cases reuse the existing repository/use-case seams:

- Fresh null session renders the existing Spanish error and retry button, with no `ShimmerCard`, published recap or private text. Two retry taps leave terminal `RecapDetailError` and zero detail/read/write/transport calls.
- Synthetic A is loaded and visibly rendered first. Explicitly clearing the injected session and requesting detail replaces A with the same error; retry does not issue another repository request. Exactly the initial A request has transport stamp `synthetic-A:1`, with zero feedback/writes.

This tests the page's response to a signed-out **detail request**, not automatic logout navigation or immediate logout observation without an event. The unchanged Bloc suite separately covers stale detail/feedback and epoch/session interleavings. Widget smoke is not installed Android/iOS proof, screenshots, human visual acceptance or native compilation.

TDD exception: coverage-only continuation, no new bug demonstrated and no fabricated RED. The earlier causal RED12/2 → GREEN14/final15 above remains historical evidence for the source fix. New widget tests passed on their first run; the three original page tests also remain green.

All commands below ran one at a time in the foreground from `exom-app`, using the parent's exact runners. No known environmental failures. UTC windows bounded by surrounding observed timestamps:

| Exact command | UTC window | Observed result |
| --- | --- | --- |
| `${RUNTIME_ROOT}/flutter/bin/flutter test --no-pub test/features/recap/presentation/pages/recap_detail_page_test.dart test/features/recap/presentation/bloc/recap_bloc_test.dart` | 12:21:26–12:22:17 | PASS exit0: 20 tests (5 page + 15 Bloc) |
| `${RUNTIME_ROOT}/flutter/bin/flutter test --no-pub` | 12:22:17–12:23:32 | PASS exit0: 544 tests; existing Hive adapter override warning observed |
| `${RUNTIME_ROOT}/flutter/bin/flutter analyze --no-pub` | 12:22:17–12:23:32, after suite | PASS exit0: 0 issues |
| `git diff --check` | After receipt update, 2026-10-08 UTC | PASS exit0: no whitespace diagnostics; untracked receipt inspected separately |

Full-suite log `${RUNTIME_ROOT}/AppData/Local/Temp/pi-bash-1ae3905825a58399.log` is **LOCAL_ONLY**, not clone-recoverable. Focused/analyzer output remains in writer tool results. No Dart edits occurred after these checks.

Final App HEAD remains `808ea370257bcd01f7cfbd4ee8a05d53bf0b2d14`, branch/upstream `fix/scoped-training-discard` / `origin/fix/scoped-training-discard`. Source plus three presentation test identities observed at `2026-10-08T12:23:32Z`:

| App-relative path | Final SHA256 |
| --- | --- |
| `lib/features/recap/presentation/bloc/recap_bloc.dart` | `ba2ee61c27bdab4860aae70f333aee857f271558a786f9e3c48b4b0b97d69656` (preserved) |
| `test/features/recap/presentation/bloc/recap_bloc_test.dart` | `10bef34946efcc175316ec225bf4fa904a4256890ec5a26edd46c7da66d6e19f` (preserved) |
| `test/features/recap/presentation/pages/recap_detail_page_test.dart` | `7d35afac99b3cc3e87b8d0d2748016f7c6655dfdcdf999e5d966f8c17c791467` |
| `test/features/recap/presentation/widgets/recap_published_review_card_test.dart` | `ae8a063212febfa7e8aedfd7e73c4ecd8c2f018f74e6b63523641c95a2d5ca6e` (preserved) |

Serialized-contract test additionally preserved: `test/features/recap/data/datasources/recap_remote_datasource_test.dart` SHA256 `929294e15a7ac0b36a6c2133ff711876c87aada91d5286b38eb196189e49f0ae`. Page test before this continuation: `a491fa5fd60e145a850843ff5fad179ea60da0cd7a805fa145e7ab72a1d65f0a`. Candidate rollback/checkpoint boundary now includes the page test alongside the earlier source/Bloc test and receipt; no Git mutation/checkpoint creation by this writer. API/Admin parent baselines remain context only, untouched here.

**Earlier writer-only stage: BUILD_NOT_RUN, verifier pending.** Parent had prepared a sequential build worktree at the same base/common Git directory; this writer neither inspected nor wrote that worktree nor launched a build. The later independent execution below supersedes only the build-pending status, not these historical observations.

### Key learnings

1. Existing use-case/repository seams allow the actual detail page and Bloc to run without application bootstrap or external services.
2. The existing error renderer already removes recap content and exposes retry; signed-out retries are verifiable through repository request counts.
3. Clearing a test session alone is not a navigation test: these assertions require an explicit detail request, matching the bounded source fix.

## REST-T3D-APP-VERIFY-01 — historical build/installed-device proposal

Prior [App receipt](../rest-t3c-app-20261008/README.md) and its `run-independent-01/build.log` were read: Gradle `assembleDebug` built `build/app/outputs/flutter-apk/app-debug.apk` from the card-only synthetic entrypoint. Neither exposes the full original CLI invocation. Old pre-B APK/hash is historical, not proof for this runtime fix.

1. Parent/verifier authorizes a fresh, dedicated checkout under the repository's home-directory sibling worktree area, imports only the reviewed candidate, verifies source/test hashes and prepares isolated non-secret dependency/build configuration. Do not build in this checkout or overwrite/copy/remove its ignored APKs/resources. No installs/dependency changes are authorized by this writer receipt.
2. Recommended compile command **in that isolated checkout only**, once prerequisites are explicitly prepared: `${RUNTIME_ROOT}/flutter/bin/flutter build apk --debug --no-pub`. Record output/hash and compiler result; never install/run the real bootstrap for this smoke. Compilation alone does not test signed-out behavior.
3. For behavioral Android smoke, separately authorize a synthetic detail-page entrypoint wiring the real Bloc/page to an owned fake repository and nullable session provider, with no real main/bootstrap/Firebase/HTTP. Use a distinct test application ID; verify no installed app is replaced and existing AVD/data/resources remain intact before launching the specifically authorized existing emulator. Do not create/reset/wipe an AVD or touch a physical device/API.
4. Exercise fresh null session, loaded A then null session/request B, repeated retry, stale feedback and late A completion. Observe terminal Spanish error, no skeleton/prior recap content and zero repository requests after sign-out. Retain logs/screenshots and APK identities in newly authorized isolated output paths. Do not claim smoke PASS from the old card harness. Native iOS is not proven by Android; applicable platform disposition belongs to the parent.

At the writer stage, build/smoke remained pending. The following observed compilation and deterministic real-Bloc/page smoke address the bounded Dart state fix; installed-device/native iOS checks remain NOT_RUN, not PASS. No full P5 closure or delivery claim is made.

## Independent verification and isolated compilation — observed by parent

| Exact command / cwd | UTC 2026-10-08 | Observed result |
| --- | --- | --- |
| Main: `${RUNTIME_ROOT}/flutter/bin/flutter test --no-pub test/features/recap/presentation/pages/recap_detail_page_test.dart test/features/recap/presentation/bloc/recap_bloc_test.dart` | 12:26:28–12:26:35 | PASS20, actual Bloc/page; terminal error, prior content/skeleton removed, signed-out retries issue no requests |
| Main: `${RUNTIME_ROOT}/flutter/bin/flutter test --no-pub` | 12:26:39–12:27:24 | PASS544, existing Hive warning |
| Main: `${RUNTIME_ROOT}/flutter/bin/flutter analyze --no-pub` | 12:27:30–12:27:45 | PASS0 issues |
| Main: `git diff --check`; explicit new receipt `git diff --no-index --check -- /dev/null docs/evidence/rest-t3d-app-20261008/README.md` | Through12:30:17 | No whitespace diagnostics; no-index exit1 means differing new file |
| Isolated: `${RUNTIME_ROOT}/flutter/bin/flutter pub get --offline` | 12:27:58–12:28:09 | PASS, lock unchanged SHA256 `8ce850ec0cb0d5e22540a418819ab221030e9bdf393e1ca50330e3b6466c1511` |
| Isolated: `${RUNTIME_ROOT}/flutter/bin/flutter build apk --debug --no-pub --dart-define=EXOM_API_BASE_URL=https://exom.test.invalid/api/v1` | 12:28:14–12:29:15 | FAIL, missing android/app/google-services.json / processDebugGoogleServices; preserved historical attempt |
| Same exact isolated build command after parent synthetic configuration | 12:31:35–12:33:06 | PASS exit0/assembleDebug; Java8/deprecated API warnings |

Isolated same-clone detached worktree `${WORKSPACE_ROOT}/.odd-worktrees/exom-app-t3d-20261008`, base `808ea370257bcd01f7cfbd4ee8a05d53bf0b2d14`, common directory `exom-app/.git`; imported candidate source hashes match main. Parent added only fake package-matched Google Services input (`com.exommethod.exom`, project `exom-isolated-ci-not-real`, invalid synthetic key), never real credentials. Build never executes application bootstrap or accesses API/Firebase. Worktree UI registration unavailable because session coordination root is non-Git; Git common-directory identity was independently verified instead.

Generated APK **LOCAL_ONLY**: `<isolated-worktree>/build/app/outputs/flutter-apk/app-debug.apk`, SHA256 `d46506a57bf3573547a562a89a0a2bc364962e5d20b4f5680e3ebbdcf9774db9`. Original main APK unchanged SHA256 `b1e89b6a2bbb8b63c8eec707c581f24d87249c4800f1800d0a5d61835cb69cfb`; resource manifest `docs/evidence/progress-remaining-20261008/checkpoint/t3d-authorized/isolated-build.json` in the non-Git coordination root. All source/test hashes above and API probe remain unchanged; Admin clean. Full-suite tool log `${RUNTIME_ROOT}/AppData/Local/Temp/pi-bash-c55801972853daa1.log` LOCAL_ONLY, not fresh-clone proof.

Smoke boundary is deterministic actual Bloc/page under Flutter host tests, not installed Android/iOS or automatic logout navigation: widget loaded-A→signed-out requests A; separate Bloc case requests B. Both PASS; no new state/product flow was introduced. No APK installation, AVD launch/reset, live identity/service/data or native iOS compilation. New review and local commit are the remaining controls for this bounded unit.
