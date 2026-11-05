package com.exom.build;

import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;
import java.util.Map;
import java.util.TreeMap;

/** Dependency-free host checks; run by verifyTimingPatch, not the Android SDK. */
public final class TimingPatchGuardsTest {
    interface Checked { void run() throws Exception; }

    private static void rejected(String message, Checked check) throws Exception {
        try {
            check.run();
            throw new AssertionError("Accepted " + message);
        } catch (IllegalStateException expected) {
            if (!expected.getMessage().contains(message)) throw expected;
        }
    }

    public static void main(String[] args) throws Exception {
        rejected("version", () -> TimingPatch.checkVersion("0.10.6"));
        rejected("AAR hash", () -> TimingPatch.originalJar(new byte[]{1, 2, 3}));
        rejected("JAR hash", () -> TimingPatch.checkHash(new byte[]{1}, TimingPatch.JAR_SHA, "JAR"));
        rejected("source hash", () -> TimingPatch.checkHash(new byte[]{1}, TimingPatch.SOURCE_SHA, "source"));
        rejected("pipeline source hash", () -> TimingPatch.checkHash(new byte[]{1},
                TimingPatch.PIPELINE_SOURCE_SHA, "pipeline source"));
        Path generated = Files.createTempDirectory("timing-generated-negative-");
        Files.writeString(generated.resolve("Unexpected.class"), "not a class");
        rejected("generated entry set", () -> TimingPatch.replacement(generated));
        rejected("JAR entry set", () -> TimingPatch.checkChanges(
                new TreeMap<>(Map.of("old", new byte[]{1})),
                new TreeMap<>(Map.of("new", new byte[]{1})), List.of(), "JAR"));
        rejected("JAR changed entries", () -> TimingPatch.checkChanges(
                new TreeMap<>(Map.of("old", new byte[]{1})),
                new TreeMap<>(Map.of("old", new byte[]{2})), List.of(), "JAR"));
        // Duplicate central/local entries, without ZipOutputStream's duplicate-name guard.
        byte[] duplicate = TimingPatch.zip(new TreeMap<>(Map.of("a", new byte[]{1}, "b", new byte[]{2})));
        for (int i = 0; i < duplicate.length - 1; i++) {
            if (duplicate[i] == 'b' && (i == 30 || duplicate[i - 1] == 0)) duplicate[i] = 'a';
        }
        rejected("Duplicate entry", () -> TimingPatch.read(duplicate));
        System.out.println("PASS patch packaging guards=9 (version/hash/source/pipeline-source/generated-set/entry-set/diff/duplicate)");
    }
}
