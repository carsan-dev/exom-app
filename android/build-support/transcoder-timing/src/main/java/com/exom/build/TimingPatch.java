package com.exom.build;

import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.File;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.MessageDigest;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HexFormat;
import java.util.List;
import java.util.Map;
import java.util.SortedMap;
import java.util.TreeMap;
import java.util.zip.CRC32;
import java.util.zip.ZipEntry;
import java.util.zip.ZipInputStream;
import java.util.zip.ZipOutputStream;

/** Fail-closed, two-source patch (DecoderDropper timing, Pipeline drain) for the reviewed Transcoder 0.10.5 artifact. */
public final class TimingPatch {
    public static final String VERSION = "0.10.5";
    public static final String CLASS = "com/otaliastudios/transcoder/internal/codec/DecoderDropper.class";
    static final String AAR_SHA = "ac93f7b7e91e0d53fe3c423756d664cef8487db9c8a6208a75a7082899cc307c";
    static final String JAR_SHA = "091f2ff1b7e4524fd63bb7b9ad6418ca164377cdec8b8528fbd36490510a2c7c";
    static final String SOURCE_SHA = "79125da002850d09f3f6c2c20ae57f478f189515e8c43ac0e720a4232451bd3c";
    public static final String CLASS_SHA = "4449ece581b59d0e50839c915c03fa2f62ff5ee19bff719fa947aadc5d924404";
    static final String PIPELINE_SOURCE_SHA = "f131785f920808f1cdcc07abacc9795d3e11fa8add546ccee8d8a20f0d3a0e1e";
    /** Every class generated from Pipeline.kt replaces its original entry; no entry is added or removed. */
    public static final SortedMap<String, String> PIPELINE_CLASS_SHA = new TreeMap<>(Map.of(
            "com/otaliastudios/transcoder/internal/pipeline/Pipeline.class",
            "648d078e140de75f7be0940b2d05f96c9ed9a8845f36bfc4f277f2b7399c7769",
            "com/otaliastudios/transcoder/internal/pipeline/Pipeline$Builder.class",
            "eede4b59ba41873eaefecc65bd7c7a2de6f1d34791b5e301a838f0c7c97ec750",
            "com/otaliastudios/transcoder/internal/pipeline/Pipeline$Companion.class",
            "0f7a155f98bebb89d15ba9d99a3d7e23c6d00327e09035bb873a6755a383aabd",
            "com/otaliastudios/transcoder/internal/pipeline/Pipeline$Companion$build$1.class",
            "c5e756b7dd14b46be680573cf154709ba8ecfc0189601f0be0e3fcffbd9fccd6",
            "com/otaliastudios/transcoder/internal/pipeline/PipelineKt.class",
            "4353433d74dbc8c872276bb9f3f895a5ab6a1bc27af89b2de9561969502e9fd1"));
    public static final String PATCHED_AAR_SHA = "ffc8927d649d53ccee62c7d323a39a8e6ec6450e254d91b8bfea6498b77afdca";
    public static final List<String> FLAGS = List.of("-no-stdlib", "-no-reflect", "-jvm-target", "1.8",
            "-language-version", "1.5", "-api-version", "1.5", "-module-name", "lib_release");

    public static void checkVersion(String version) {
        if (!VERSION.equals(version)) throw new IllegalStateException("Unexpected Transcoder version: " + version);
    }

    static String hash(byte[] bytes) throws Exception {
        return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(bytes));
    }

    static void checkHash(byte[] bytes, String expected, String label) throws Exception {
        if (!hash(bytes).equals(expected)) throw new IllegalStateException("Unexpected " + label + " hash");
    }

    public static SortedMap<String, byte[]> read(byte[] bytes) throws Exception {
        SortedMap<String, byte[]> entries = new TreeMap<>();
        try (ZipInputStream zip = new ZipInputStream(new ByteArrayInputStream(bytes))) {
            ZipEntry entry;
            while ((entry = zip.getNextEntry()) != null) {
                if (entries.put(entry.getName(), zip.readAllBytes()) != null) {
                    throw new IllegalStateException("Duplicate entry: " + entry.getName());
                }
            }
        }
        return entries;
    }

    static byte[] zip(SortedMap<String, byte[]> entries) throws Exception {
        ByteArrayOutputStream bytes = new ByteArrayOutputStream();
        try (ZipOutputStream zip = new ZipOutputStream(bytes)) {
            for (var entry : entries.entrySet()) {
                byte[] data = entry.getValue();
                ZipEntry output = new ZipEntry(entry.getKey());
                output.setTimeLocal(LocalDateTime.of(1980, 1, 1, 0, 0));
                output.setMethod(ZipEntry.STORED);
                output.setSize(data.length);
                CRC32 crc = new CRC32();
                crc.update(data);
                output.setCrc(crc.getValue());
                zip.putNextEntry(output);
                zip.write(data);
                zip.closeEntry();
            }
        }
        return bytes.toByteArray();
    }

    static byte[] originalJar(byte[] aar) throws Exception {
        checkHash(aar, AAR_SHA, "AAR");
        byte[] jar = read(aar).get("classes.jar");
        if (jar == null) throw new IllegalStateException("Original classes.jar absent");
        checkHash(jar, JAR_SHA, "JAR");
        return jar;
    }

    /** Expected class hashes keyed by JAR entry: the timing class plus every Pipeline.kt class. */
    static SortedMap<String, String> replacedClasses() {
        SortedMap<String, String> expected = new TreeMap<>(PIPELINE_CLASS_SHA);
        expected.put(CLASS, CLASS_SHA);
        return expected;
    }

    static SortedMap<String, byte[]> replacement(Path generated) throws Exception {
        List<String> actual;
        try (var files = Files.walk(generated)) {
            actual = files.filter(Files::isRegularFile)
                    .map(generated::relativize).map(Path::toString).map(p -> p.replace('\\', '/')).sorted().toList();
        }
        List<String> expectedEntries = new ArrayList<>(replacedClasses().keySet());
        expectedEntries.add("META-INF/lib_release.kotlin_module");
        expectedEntries.sort(null);
        if (!actual.equals(expectedEntries)) {
            throw new IllegalStateException("Unexpected generated entry set: " + actual);
        }
        SortedMap<String, byte[]> classes = new TreeMap<>();
        for (var entry : replacedClasses().entrySet()) {
            byte[] bytes = Files.readAllBytes(generated.resolve(entry.getKey()));
            checkHash(bytes, entry.getValue(), "replacement class " + entry.getKey());
            classes.put(entry.getKey(), bytes);
        }
        return classes;
    }

    static void checkChanges(Map<String, byte[]> before, Map<String, byte[]> after,
                             List<String> expected, String label) {
        if (!before.keySet().equals(after.keySet())) throw new IllegalStateException(label + " entry set changed");
        List<String> changed = before.keySet().stream()
                .filter(key -> !Arrays.equals(before.get(key), after.get(key))).toList();
        if (!changed.equals(expected)) throw new IllegalStateException(label + " changed entries: " + changed);
    }

    public static void build(Path original, Path source, Path pipelineSource, String compilerClasspath, Path stdlib,
                             Path java, List<String> flags, Path work, Path output) throws Exception {
        if (!flags.equals(FLAGS)) throw new IllegalStateException("Unexpected compiler flags");
        byte[] aarBytes = Files.readAllBytes(original);
        byte[] jarBytes = originalJar(aarBytes);
        checkHash(Files.readAllBytes(source), SOURCE_SHA, "source");
        checkHash(Files.readAllBytes(pipelineSource), PIPELINE_SOURCE_SHA, "pipeline source");
        Files.createDirectories(work);
        Path jar = work.resolve("original-classes.jar");
        Files.write(jar, jarBytes);
        Path generated = work.resolve("generated");
        List<String> command = new ArrayList<>(List.of(java.toString(), "-cp", compilerClasspath,
                "org.jetbrains.kotlin.cli.jvm.K2JVMCompiler"));
        command.addAll(flags);
        // Pipeline.kt uses the module's internal Step/State API; the pinned original JAR is its friend module.
        command.add("-Xfriend-paths=" + jar);
        command.addAll(List.of("-classpath", jar + File.pathSeparator + stdlib,
                "-d", generated.toString(), source.toString(), pipelineSource.toString()));
        Path log = work.resolve("compiler.log");
        int exit = new ProcessBuilder(command).redirectErrorStream(true).redirectOutput(log.toFile()).start().waitFor();
        if (exit != 0) throw new IllegalStateException("Timing patch compilation failed (" + exit + "): " + log);
        var beforeJar = read(jarBytes);
        var afterJar = new TreeMap<>(beforeJar);
        afterJar.putAll(replacement(generated));
        byte[] resultJar = zip(afterJar);
        checkChanges(beforeJar, read(resultJar), new ArrayList<>(replacedClasses().keySet()), "JAR");
        var beforeAar = read(aarBytes);
        var afterAar = new TreeMap<>(beforeAar);
        afterAar.put("classes.jar", resultJar);
        byte[] resultAar = zip(afterAar);
        checkChanges(beforeAar, read(resultAar), List.of("classes.jar"), "AAR");
        Files.write(output, resultAar);
    }

    public static void verifyPatched(Path aar) throws Exception {
        byte[] bytes = Files.readAllBytes(aar);
        checkHash(bytes, PATCHED_AAR_SHA, "resolved AAR");
        var classes = read(read(bytes).get("classes.jar"));
        for (var entry : replacedClasses().entrySet()) {
            checkHash(classes.get(entry.getKey()), entry.getValue(), "resolved replacement class " + entry.getKey());
        }
    }
}
