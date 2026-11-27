# Pinned Transcoder timing and pipeline-drain patch

Two reviewed source files replace classes in `com.otaliastudios:transcoder:0.10.5`:
`source/DecoderDropper.kt` (timing, one class) and `source/Pipeline.kt` (encoder drain
before `VideoPublisher` swaps, the five classes generated from `Pipeline.kt`).
No binary is vendored; no downloaded artifact is modified. `PROVENANCE.txt`,
`upstream/`, `LICENSE` and `NOTICE` retain the reviewed source and attribution.
Additional applicable upstream notices must be checked before distribution.

## Verification

From `android/` (use the platform's Gradle wrapper):

```text
gradlew --offline -p build-support/transcoder-timing verifyTimingPatch
gradlew --offline verifyTranscoderTimingResolution
gradlew --offline :app:assembleDebug
```

Offline checks require the pinned dependencies and JDK 17 already installed.
Host tests compile independent artifacts, demonstrate the original timing failure,
then exercise fixture schedules, differential behavior and packaging guards.
Android artifact/runtime validation is separate; host success is not native acceptance.

## Packaging boundary

The root plugin marks only the pinned module's variants with a private original
AAR artifact type, then transforms it into an ordinary AAR. AGP's existing AAR
extraction/DEX transforms run afterwards. Module dependency metadata is retained.
An original/patched attribute requested on configurations was rejected: that
mismatch fails graph variant selection before Gradle can select an artifact transform.

The transform declares both sources, compiler/stdlib classpaths, compiler flags/version,
and selected JDK contents/identity as inputs. Hash guards bind original AAR/JAR,
sources and every generated class to the reviewed bytes. Sorted, stored ZIP entries have
fixed timestamps. Only `DecoderDropper.class` and the five `Pipeline*.class` entries are
replaced (no entry added or removed); the compiler's partial Kotlin module index is
discarded and the complete original index is preserved. `Pipeline.kt` uses the module's
internal API, so the pinned original JAR is passed as `-Xfriend-paths` at build time.
Any module upgrade requires explicit review and replacement of this pinned patch.
