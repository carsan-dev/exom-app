# REST-T3C2 — App publication consumer

> Copia saneada para entrega: ubicaciones normalizadas; resultados, fechas y hashes conservan su significado histórico y corresponden al snapshot privado original, no a esta copia. WORKSPACE_ROOT identifica la coordinación; SDK_ROOT el SDK instalado; RUNTIME_ROOT las herramientas locales; TEST_ARTIFACT_ROOT los recursos privados retenidos, no publicados.


Date: 2026-10-08. **REST-T3C2 DONE locally** in `afb7230cb365c8ae67a085e81cc1e44440327a6f`: native SUCCESS and exact ACK CONSUMED, with independent functional evidence preserved. The passive receipt commit is pending parent disposition. Platform smoke remains separate; P5 and integrated REST-T3C3 acceptance are not closed.

## Scope and identity

- Coordination root: `${WORKSPACE_ROOT}/`, non-Git according to the parent CURRENT task; no repository initialized. Read-only documentation snapshot: AGENTS SHA256 `f21dc8259e9ff8b7a02122efd9b1651a4a22859081c6871722b099c8476a38db`, plan `9b6eb9d0d5e4043a4d466f08ef16897f333f3bec588777b5f084768056e86e05`, CURRENT task `8b30abf45285455e047ad6105be690eb5e62fa3a40c6056fbe7fd536629fd45a`.
- App root: `${WORKSPACE_ROOT}/exom-app`; observed clean baseline HEAD `db72c7feee2c3ba91bc71068a7918903179ca78d`, branch `fix/scoped-training-discard`, upstream `origin/fix/scoped-training-discard`. No staging or Git mutations.
- API reference: parent-verified `2860703d8e00dc6a096a02c0c4b37543c0cd514a`. Read-only inspection of `src/modules/recaps/recaps.service.ts`: `CLIENT_RECAP_SELECT` exposes only the three published review fields, not drafts, version or internal notes. No API/Admin changes.
- Strict TDD: explicit parent test-first authorization and exact Flutter runner. Environment: Windows, parent-verified Flutter 3.41.5 / Dart 3.11.3, PATH `${RUNTIME_ROOT}/flutter/bin`. No pub get, dependency changes, live Firebase/API, physical device or production action. The later parent-authorized independent synthetic Android debug build is recorded below.
- Applicable skills read in full: injected Impeccable SKILL and craft-floor. Context launcher not run (outside approved commands); preserved incumbent Recap implementation as visual truth. CodeGraph read-only query used before code mapping.

## Criteria and implementation

P5-02 bounded App consumer: nullable `publishedCoachSummary`, `publishedChanges`, `publishedNextWeekGoals`, compatible with legacy/absent/null payloads and preserved by legacy feedback `copyWith`. Drafts/internal/version have no entity representation or rendering fallback. Create/update strip review-only fields without changing incumbent explicit-null clearing of client form data.

New `RecapPublishedReviewCard` uses incumbent card decoration, palette, spacing and typography. Read-only Spanish section headings; each nonblank publication independently controls visibility. No status, legacy-feedback or all-three-required publication inference; server-confirmed values are canonical. Whitespace-only sections disappear; multiline and unbroken text wrap, without truncation. Legacy feedback card remains unedited, and publication alone never dispatches a feedback read.

Causal dependency REST-T3C2-DETAIL-01: actual existing Bloc emitted late detail A after newer B; old errors also replaced successful B. A captured pre-await feedback state resurrected A. Account/generation/logout changes allowed stale detail emissions and feedback UI updates. Behavioral RED reproduced all of these before changing the allowed Bloc. Minimum correction: per-detail epoch, canonical `LocalStorage.sessionStamp`, `sessionTask` transport zone and pre/post-await feedback checks using current state. Optional storage injection defaults to registered `sl<LocalStorage>()`; existing factory needs no edits. No global auth gate/refactor, queue, notification or publication writer.

Tests use owned synthetic repository completers and GetIt registrations; no Firebase/Hive initialization. Verify `uid:generation` request-zone propagation, late success/error suppression, all three session transitions, legacy read behavior and create/save/update/submit/list compatibility. Geometry/semantics matrix: 320px, Android/iOS ThemeData, light/dark, font scale 1 and 2, long unbroken content and paragraphs; no overflow/truncation and semantic headings.

## Observed validation

Exact focused command (all four paths exist before first run):

```text
flutter test --no-pub test/features/recap/data/models/recap_model_test.dart test/features/recap/presentation/widgets/recap_published_review_card_test.dart test/features/recap/presentation/pages/recap_detail_page_test.dart test/features/recap/presentation/bloc/recap_bloc_test.dart
```

| Command / stage | Observed result | LOCAL_ONLY log |
| --- | --- | --- |
| Focused RED, before source edits | FAIL: 7 PASS / 11 intended behavioral FAIL (not compilation failures) | `run-writer-01/red.log` |
| Focused initial GREEN | PASS: 18 | `run-writer-01/green-initial.log` |
| Focused expanded triangulation | FAIL: 26 PASS / 8 fixture failures; all active SemanticsHandles disposed too late in test teardown | `run-writer-01/green-final.log` |
| Focused corrected triangulation | PASS: 34; `finally` disposes handles before Flutter end verification | `run-writer-01/green-corrected.log` |
| `flutter test --no-pub` initial | PASS: 536 | `run-writer-01/full.log` |
| `flutter analyze --no-pub` initial | FAIL: 2 new test-only infos (redundant import, deprecated hasFlag) | `run-writer-01/analyze.log` |
| Focused final after test API cleanup | PASS: 34 | `run-writer-01/focused-final.log` |
| `flutter test --no-pub` final | PASS: 536 | `run-writer-01/full-final.log` |
| `flutter analyze --no-pub` final | PASS: 0 issues | `run-writer-01/analyze-final.log` |
| `git diff --check` | PASS: exit 0, no output | Writer tool result |

`dart format` was a separate authorized edit on the nine changed product/test Dart paths, then on the owned card test and synthetic entrypoint; never a broad formatter. The final focused/full/analyze runs follow the final Dart edits. No assertions/tests were removed or disabled. Historical failed logs retained unchanged. Full suite emitted an unrelated Hive adapter-override warning but passed; no claim that this warning was introduced or repaired here.

## Independent verification receipt

Parent-authorized independent results, inspected from `run-independent-01/` (no functional checks rerun during this documentation-only normalization):

| Check | Observed result | LOCAL_ONLY log |
| --- | --- | --- |
| Same four-path focused Flutter command above | PASS: 34 | `focused.log` |
| `flutter test --no-pub` | PASS: 536 | `full.log` |
| `flutter analyze --no-pub` | PASS: 0 issues | `analyze.log` |
| `git diff --check` | PASS: no output, as reported by parent | `diff-check.log` |
| Synthetic entrypoint Android debug APK target | PASS: Gradle `assembleDebug` built APK; not installation/smoke | `build.log` |
| Original writer checkpoint identities | All 13 SHA256 values unchanged before this README edit | `hashes-after.log` |

Built `build/app/outputs/flutter-apk/app-debug.apk`: 172772119 bytes, SHA256 `b1e89b6a2bbb8b63c8eec707c581f24d87249c4800f1800d0a5d61835cb69cfb`. Both previous output APK copies were retained under `run-independent-01/apk-before/`, preserving their output-relative paths and SHA256 `54dc95e72a97fa7bef437c5b936b9c6808dc6f685958f06d313cdb705ccc2525` (`apk-preservation.log`). These are local synthetic build artifacts, not production or native iOS validation.

## Final source SHA256

| Path | SHA256 |
| --- | --- |
| `lib/features/recap/domain/entities/recap_entity.dart` | `c1f5792879b636846d359ceb2d81ef4402af73bc1698a286e871fd5b7aa03f7d` |
| `lib/features/recap/data/models/recap_model.dart` | `944ec9fe55145c9a27ee52e95699ea11dd01e59fe49d188200e84464ef7b5492` |
| `lib/features/recap/presentation/pages/recap_detail_page.dart` | `2fc34aef202be63b262aa0b34ef39db47f5d875a5e15c589da7e17ee15d1d1c7` |
| `lib/features/recap/presentation/widgets/recap_published_review_card.dart` | `e194416d57d7049f2fc29dae06b130eff2371b07965b67650e7fe7387e49640d` |
| `lib/features/recap/presentation/bloc/recap_bloc.dart` | `e2a1abb9ca10c20142aabc7006f90e748492430ac8b7c9ab571416e5f2e8df92` |

Historical test/config/harness hashes and exact writer snapshots remain in `checkpoint/writer-final/manifest.json`, preserved unchanged. Documentation normalization is captured manually in `checkpoint/native-docs/manifest.json`: all 13 current worktree SHA256 values and Git blob IDs, original writer hashes, final `README.md.snapshot`, and a read-only tracked patch against the last HEAD. Only README differs from the original 13 identities; this bookkeeping is not a validator, review receipt or commit. The existing `checkpoint.cjs` was neither edited nor invoked. The authored product/test delta is approximately 725 lines including new files, inside the 500–800 forecast; generated artifacts excluded.

## Recovery and limits

`checkpoint.cjs` is an offline bounded recovery writer: exact non-secret allowed paths only, no network/dependencies or Git mutations. Its output `checkpoint/writer-final/` retains 13 source/test/config/doc/script snapshots, tracked patch and manifest with branch/upstream/HEAD/status/empty-index evidence. `.gitignore` adds only this unit's run directories/checkpoint; incumbent `*.log` already ignores logs. These generated bundles are **LOCAL_ONLY**, not available in a fresh clone unless separately archived. Authored README, entrypoint and checkpoint writer remain visible for parent disposition.

`recap_ui_harness.dart` is a prepared synthetic entrypoint rendering only the new card in incumbent light/dark themes. It imports no real main/bootstrap, service locator, Firebase or HTTP. Synthetic Android debug build **PASS** in the independent receipt above; installation/device smoke **NOT_RUN**. Simulated iOS ThemeData does not prove native iOS execution. Parent read-only auth-flow challenge found that normal flow emits `AuthLoading` and triggers GoRouter redirect before account B becomes active. This does not test immediate outgoing-page visual removal, nor guarantee removal for external identity replacement. Already-displayed state removal remains owned by the incumbent auth/router lifecycle; this correction specifically suppresses late responses and feedback operations from previous sessions, not a global auth redesign.

## Historical native tooling blocker — REST-T3C2-NATIVE-01 (workflow resolved below)

2026-10-08, parent-reported evidence: **BLOCKED maintenance/tooling; root cause unproven**, REST-T3C2 remains IN_PROGRESS, not approved or committed. First native INSPECT failed with fatal Go runtime panic (`unknown caller pc`/`gopark`), exit2, empty output and incomplete inventory; no mutation. Separate verifier identified native4.0.0 at `${RUNTIME_ROOT}/go/bin/gentle-ai.exe`, built go1.27.1 Windows/amd64 CGO0. These identities are discoveries, not proof of a causal Go bug. A fresh facade INSPECT then succeeded with complete inventory, offering `review-8c4ca87e51b17324`, candidate `ada53b37aaf4ae38d612df7c8d847dfe43180877`, target `sha256:57db1f24df9338f3794344dd971ac02435a437368f0521a523462826dc483b0e`; START failed `native-operation-failed`, `lineage_created=false`, mutation=false. The next fresh INSPECT repeated panic/incomplete inventory. No actual review lineage exists; the offered ID is not an active review.

Independent focused34/full536/analyze0/synthetic debug APK PASS remain intact; this tooling failure does not downgrade them or establish an App defect. No STATUS of the offered ID, recover/reset, RDD disabling, installation, GOGC workaround or further START until native inventory is complete. Parent must obtain user authorization before bounded global tooling repair or disposition to leave native review pending; neither is authorized by this receipt. No commit/push, P5 DONE or external delivery. Platform installation/smoke and native iOS remain unproven.

Historical recovery checkpoint `checkpoint/native-blocked/manifest.json` manually preserves all 13 authored current files as complete `.snapshot` bytes, SHA256/Git blob IDs and tracked patch against App HEAD `db72c7feee2c3ba91bc71068a7918903179ca78d`, including this incident-updated README. It records dated non-Git coordination hashes before/after. Original checkpoints, generated logs and APK remain unchanged in place; no bulk artifact copies. This is writer bookkeeping, not independent validation or a native receipt. API `2860703` original probe and Admin `2e5d43d` unchanged; root plan and CURRENT task retain acceptance unchanged. At that historical checkpoint, the next action was the user's tooling/review disposition, not another start retry or automatic next feature.

## Passive local closure — 2026-10-08

This section supersedes only the earlier pending review/commit and tooling workflow status, not historical failed logs, acceptance criteria or platform limits. Source of native/precommit facts: the parent's observed completed transaction; this documentation writer did not invoke native tooling or mutate Git.

| Closure fact | Evidence / origin |
| --- | --- |
| Implementation commit | Parent-created `afb7230cb365c8ae67a085e81cc1e44440327a6f`, `feat(app): muestra revisiones publicadas de recap`; base `db72c7feee2c3ba91bc71068a7918903179ca78d` |
| Commit tree | `0320bc1436ca2c4c81594ef7e8cce2bf90b85a7e`, read-only HEAD verification; parent confirms exact native-approved/staged equality, base tree `048461adcbd1d250b89ac7c54f807028967a6a03` |
| Approved scope / precommit | 13 paths, 889 insertions / 13 deletions (902 lines); parent-observed 13/13 raw and Git-filtered hashes, tree equality and staged diff-check PASS; empty indexes, no native hooks/gitattrs, autocrlf=false |
| Native review | `review-750eefe2e019f358` SUCCESS; medium risk, one consolidated `review-reliability` review |
| Exact acknowledgement | CONSUMED, revision `sha256:e7e32bbc5598ddba3ef34825fa3b83c7f20994bef85decbb1dcd1cb5a6f06c32` |
| Burn evidence | `gentle-ai.review-acknowledged/v1`, target `sha256:1e4c6f3822358f023020420431ec06330f09031cf402987a62c0229be421a662`; authority burned, no subsequent STATUS/CLI/facade/advisory reopening/correction |
| Tooling issue | REST-T3C2-NATIVE-01 RESOLVED for workflow following user-owned repair and successful review; root cause remains unproven, new binary metadata NOT_CHECKED |
| Evidence applicability | Independent focused34/full536/analyze0/synthetic APK PASS logs reread; 9/9 product/test SHA256 hashes match writer-final manifest and current committed bytes. No tests/build rerun for passive text |
| Worktree | App clean before receipt edit, branch/upstream `fix/scoped-training-discard` / `origin/fix/scoped-training-discard`; API `2860703` only original probe, Admin `2e5d43d` clean, observed read-only at `2026-10-08T11:18:28+02:00` |

Initial global Go1.27.1 diagnosis does not prove causality. Later parent evidence distinguishes bundled Go1.27.1 from global Go1.26.8 but does not certify the actual failed executable path. No tooling repair root cause or new Go binary identity is claimed. Earlier panics/START failures remain dated FAIL evidence.

Separate informational follow-up: **`R3-signed-out-loading` OPEN**, reliability WARNING at exact source `lib/features/recap/presentation/bloc/recap_bloc.dart:185`, assigned to REST-T3D. Obtain the full finding, reproduce/dispose and add regression coverage if applicable; no fabricated diagnosis or full finding text. Native approval stands; no correction opened.

The user's resumed P5 authorization supersedes the night pause, not scope/criteria. REST-T3C3 is IN_PROGRESS for integrated acceptance mapping only: publication/last published version during draft, nullable/legacy privacy, identity/generation/late responses and complete private-safe printing, including missing-submission/archived cases. New integrated checks NOT_RUN. Existing Admin browser14/14 and actual PDF10/10 PASS remain bounded evidence; parent visually inspected three pages, not all 68. REST-T3D remains PENDING; REST-P5-FINAL/P5 remain in progress. P5-04 Dashboard parity remains deferred to P6 PENDING, not PASS; no P6 implementation or remote delivery started. REST-DELIVERY-01 remains authorized only after P5 closure.

Synthetic APK remains 172772119 bytes, SHA256 `b1e89b6a2bbb8b63c8eec707c581f24d87249c4800f1800d0a5d61835cb69cfb`; synthetic entrypoint has no Firebase/bootstrap/HTTP integration. No real installation/device smoke/native iOS/live Firebase/JWT integration/user visual approval is claimed.

Recovery: new ignored LOCAL_ONLY `checkpoint/committed-afb7230/manifest.json`, `root-before.json` and `root-after.json` record dated path/SHA256 snapshots, complete before/after `.snapshot` copies of task/plan/receipt, observed commit/tree and parent-sourced consumed-authority facts. Previous checkpoint directories/logs/APK remain untouched; no `.gitignore` edit. Root is non-Git, no initialization. This README update is passive text only (meaningful behavioral RED/GREEN NOT_APPLICABLE); a separate documentation-only commit belongs to the parent and is **PENDING**, with no future SHA invented.
