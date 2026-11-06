package com.exom.build;

import java.net.URL;
import java.net.URLClassLoader;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import javax.tools.JavaCompiler;
import javax.tools.ToolProvider;

/**
 * Host-only Pipeline drain regression. The probe sources under src/test/pipeline-probe are compiled at test
 * time against the pinned original JAR (the Gradle test source set has no Transcoder classpath), then the same
 * finite-credit model runs in isolated loaders over original and patched Pipeline bytes. The host stub
 * VideoPublisher is first on each isolated path; it is never packaged. Model only, not Android proof.
 */
public final class PipelineDrainSelfCheck {
    @SuppressWarnings("unchecked")
    static List<String> run(Path probeClasses, Path jar, Path stdlib) throws Exception {
        URL[] urls = {probeClasses.toUri().toURL(), jar.toUri().toURL(), stdlib.toUri().toURL()};
        try (URLClassLoader loader = new URLClassLoader(urls, ClassLoader.getPlatformClassLoader())) {
            Class<?> publisher = loader.loadClass("com.otaliastudios.transcoder.internal.video.VideoPublisher");
            if (!publisher.getProtectionDomain().getCodeSource().getLocation().toString().equals(urls[0].toString())) {
                throw new AssertionError("Host stub VideoPublisher is not first on the isolated class path");
            }
            return (List<String>) loader.loadClass("com.exom.egl.PipelineDrainProbe").getMethod("run").invoke(null);
        }
    }

    static void expect(List<String> lines, String prefix, String expected) {
        String line = lines.stream().filter(l -> l.startsWith(prefix)).findFirst()
                .orElseThrow(() -> new AssertionError("Missing scenario " + prefix));
        if (!line.contains(expected)) throw new AssertionError("Scenario '" + line + "' lacks '" + expected + "'");
    }

    public static void main(String[] args) throws Exception {
        Path original = Path.of(args[0]), patched = Path.of(args[1]), stdlib = Path.of(args[2]);
        Path sources = Path.of(args[3]), work = Path.of(args[4]), classes = work.resolve("classes");
        Files.createDirectories(classes);
        List<String> options = new ArrayList<>(List.of("-nowarn", "-d", classes.toString(), "-classpath",
                original + java.io.File.pathSeparator + stdlib));
        try (var files = Files.walk(sources)) {
            files.filter(p -> p.toString().endsWith(".java")).map(Path::toString).sorted().forEach(options::add);
        }
        JavaCompiler compiler = ToolProvider.getSystemJavaCompiler();
        if (compiler == null || compiler.run(null, null, null, options.toArray(String[]::new)) != 0) {
            throw new AssertionError("Pipeline probe compilation failed");
        }
        List<String> before = run(classes, original, stdlib);
        List<String> after = run(classes, patched, stdlib);
        expect(before, "ready-before-publish video=true", "released=1 readyLeft=2");
        expect(after, "ready-before-publish video=true", "released=3 readyLeft=0");
        expect(before, "ready-before-publish video=false", "released=1 readyLeft=2");
        expect(after, "ready-before-publish video=false", "released=1 readyLeft=2");
        expect(before, "upstream-wait", "drainCalls=0");
        expect(after, "upstream-wait", "drainCalls=0");
        expect(after, "downstream-wait-during-catch-up",
                "IllegalStateException Step Writer waited while draining before publish");
        int cases = 0;
        for (int capacity : new int[]{3, 4, 8, 16, 31}) {
            expect(before, "startup capacity=" + capacity + " delay=0 ", "blockedAt=0 submitted=128 released=128");
            expect(after, "startup capacity=" + capacity + " delay=0 ", "blockedAt=0 submitted=128 released=128");
            expect(before, "startup capacity=" + capacity + " delay=" + capacity + " ", "blockedAt=" + (capacity + 1));
            expect(after, "startup capacity=" + capacity + " delay=" + capacity + " ",
                    "blockedAt=0 submitted=128 released=128");
            cases++;
        }
        System.out.println("PASS RED original delayed-startup blocks=" + cases + "; GREEN patched completes=" + cases
                + "; non-video and upstream-wait unchanged; downstream wait fails closed (host model only)");
    }
}
