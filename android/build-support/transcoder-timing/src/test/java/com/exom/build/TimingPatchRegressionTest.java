package com.exom.build;

import java.io.File;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

public final class TimingPatchRegressionTest {
    public static void main(String[] args) throws Exception {
        Path original = Path.of(args[0]), stdlib = Path.of(args[2]), java = Path.of(args[3]), root = Path.of(args[4]);
        Path work = Files.createTempDirectory("exom-timing-host-regression-");
        Path source = root.resolve("source/DecoderDropper.kt"), pipelineSource = root.resolve("source/Pipeline.kt");
        Path first = work.resolve("first.aar"), second = work.resolve("second.aar");
        TimingPatch.build(original, source, pipelineSource, args[1], stdlib, java, TimingPatch.FLAGS, work.resolve("first"), first);
        TimingPatch.build(original, source, pipelineSource, args[1], stdlib, java, TimingPatch.FLAGS, work.resolve("second"), second);
        if (!Arrays.equals(Files.readAllBytes(first), Files.readAllBytes(second))) {
            throw new AssertionError("Independent clean builds differ");
        }
        TimingPatch.verifyPatched(first);
        var mutatedEntries = TimingPatch.read(Files.readAllBytes(first));
        byte[] manifest = mutatedEntries.get("AndroidManifest.xml");
        mutatedEntries.put("AndroidManifest.xml", Arrays.copyOf(manifest, manifest.length + 1));
        Path mutated = work.resolve("non-class-mutation.aar");
        Files.write(mutated, TimingPatch.zip(mutatedEntries));
        TimingPatch.checkHash(TimingPatch.read(mutatedEntries.get("classes.jar")).get(TimingPatch.CLASS),
                TimingPatch.CLASS_SHA, "test replacement class");
        try {
            TimingPatch.verifyPatched(mutated);
            throw new AssertionError("Accepted non-class mutation with valid replacement class");
        } catch (IllegalStateException expected) {
            if (!expected.getMessage().contains("resolved AAR hash")) throw expected;
            System.out.println("PASS resolved whole-AAR guard rejects non-class mutation with valid replacement class");
        }
        byte[] originalJar = TimingPatch.originalJar(Files.readAllBytes(original));
        Path baseline = work.resolve("baseline.jar");
        Files.write(baseline, originalJar);
        Path patched = work.resolve("patched.jar");
        Files.write(patched, TimingPatch.read(Files.readAllBytes(first)).get("classes.jar"));
        Path recompiled = work.resolve("recompiled");
        List<String> command = new ArrayList<>(List.of(java.toString(), "-cp", args[1],
                "org.jetbrains.kotlin.cli.jvm.K2JVMCompiler"));
        command.addAll(TimingPatch.FLAGS);
        command.addAll(List.of("-classpath", baseline + File.pathSeparator + stdlib,
                "-d", recompiled.toString(), root.resolve("upstream/DecoderDropper.kt").toString()));
        int exit = new ProcessBuilder(command).redirectErrorStream(true)
                .redirectOutput(work.resolve("baseline-compiler.log").toFile()).start().waitFor();
        if (exit != 0) throw new AssertionError("Baseline compilation failed; logs=" + work);
        var recompiledJar = TimingPatch.read(originalJar);
        recompiledJar.put(TimingPatch.CLASS, Files.readAllBytes(recompiled.resolve(TimingPatch.CLASS)));
        Path rebuilt = work.resolve("recompiled.jar");
        Files.write(rebuilt, TimingPatch.zip(recompiledJar));
        String[] cases = {baseline.toString(), rebuilt.toString(), baseline.toString(), stdlib.toString(),
                root.resolve("src/test/fixtures").toString()};
        try {
            PatchSelfCheck.main(cases);
            throw new IllegalStateException("Original unexpectedly passes reordered PTS regression");
        } catch (AssertionError expected) {
            if (!expected.getMessage().contains("all PTS preserved")) throw expected;
            System.out.println("PASS RED original fails reordered PTS: " + expected.getMessage());
        }
        cases[2] = patched.toString();
        PatchSelfCheck.main(cases);
        // Pipeline drain: same finite-credit host model against original and patched Pipeline bytes.
        PipelineDrainSelfCheck.main(new String[]{baseline.toString(), patched.toString(), stdlib.toString(),
                root.resolve("src/test/pipeline-probe").toString(), work.resolve("pipeline-probe").toString()});
        System.out.println("PASS independent clean builds SHA256=" + TimingPatch.hash(Files.readAllBytes(first)));
        System.out.println("Host artifacts/logs=" + work);
    }
}
