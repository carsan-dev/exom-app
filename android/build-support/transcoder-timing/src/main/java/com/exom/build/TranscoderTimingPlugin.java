package com.exom.build;

import org.gradle.api.Plugin;
import org.gradle.api.Project;
import org.gradle.api.artifacts.ComponentMetadataContext;
import org.gradle.api.artifacts.ComponentMetadataRule;
import org.gradle.api.artifacts.Configuration;
import org.gradle.api.artifacts.ExternalModuleDependency;
import org.gradle.api.artifacts.component.ModuleComponentIdentifier;
import org.gradle.api.attributes.Attribute;
import org.gradle.jvm.toolchain.JavaLanguageVersion;
import org.gradle.jvm.toolchain.JavaToolchainService;

import java.io.File;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

public final class TranscoderTimingPlugin implements Plugin<Project> {
    private static final Attribute<String> ARTIFACT_TYPE = Attribute.of("artifactType", String.class);
    private static final String ORIGINAL_AAR = "exom-transcoder-original-aar";
    private static final String MODULE = "com.otaliastudios:transcoder";

    public abstract static class OriginalVariant implements ComponentMetadataRule {
        @Override public void execute(ComponentMetadataContext context) {
            TimingPatch.checkVersion(context.getDetails().getId().getVersion());
            // A configuration-level original/patched mismatch fails graph selection before transforms.
            context.getDetails().allVariants(variant -> variant.attributes(a -> a.attribute(ARTIFACT_TYPE, ORIGINAL_AAR)));
        }
    }

    private static Configuration compilerDependency(Project root, String name, List<String> modules) {
        Configuration configuration = root.getConfigurations().create(name, c -> {
            c.setCanBeConsumed(false);
            c.setCanBeResolved(true);
            c.setTransitive(false);
        });
        for (String module : modules) {
            ExternalModuleDependency dependency = (ExternalModuleDependency) root.getDependencies().create(module);
            dependency.setTransitive(false);
            dependency.version(v -> v.strictly(module.substring(module.lastIndexOf(':') + 1)));
            configuration.getDependencies().add(dependency);
        }
        return configuration;
    }

    @Override public void apply(Project root) {
        if (root != root.getRootProject()) throw new IllegalStateException("Apply timing patch only to Android root");
        root.getPluginManager().apply("jvm-toolchains");
        Configuration compiler = compilerDependency(root, "exomTimingCompiler", List.of(
                "org.jetbrains.kotlin:kotlin-compiler-embeddable:1.8.22",
                "org.jetbrains.kotlin:kotlin-stdlib:1.8.22",
                "org.jetbrains.kotlin:kotlin-reflect:1.6.10",
                "org.jetbrains.intellij.deps:trove4j:1.0.20200330",
                "org.jetbrains:annotations:13.0"));
        Configuration stdlib = compilerDependency(root, "exomTimingStdlib", List.of(
                "org.jetbrains.kotlin:kotlin-stdlib:1.8.22"));
        JavaToolchainService toolchains = root.getExtensions().getByType(JavaToolchainService.class);
        var launcher = toolchains.launcherFor(spec -> spec.getLanguageVersion().set(JavaLanguageVersion.of(17)));
        var source = root.getLayout().getProjectDirectory()
                .file("build-support/transcoder-timing/source/DecoderDropper.kt");
        var pipelineSource = root.getLayout().getProjectDirectory()
                .file("build-support/transcoder-timing/source/Pipeline.kt");

        root.allprojects(project -> {
            project.getDependencies().getComponents().withModule(MODULE, OriginalVariant.class);
            project.getDependencies().registerTransform(TimingTransform.class, spec -> {
                spec.getFrom().attribute(ARTIFACT_TYPE, ORIGINAL_AAR);
                spec.getTo().attribute(ARTIFACT_TYPE, "aar");
                spec.parameters(p -> {
                    p.getSource().set(source);
                    p.getPipelineSource().set(pipelineSource);
                    p.getCompilerClasspath().from(compiler);
                    p.getStdlib().from(stdlib);
                    p.getJavaHome().set(launcher.map(j -> j.getMetadata().getInstallationPath()));
                    p.getJavaIdentity().set(launcher.map(j -> j.getMetadata().getVendor() + ":"
                            + j.getMetadata().getJavaRuntimeVersion() + ":" + j.getMetadata().getJvmVersion()));
                    p.getJavaExecutable().set(launcher.map(j -> j.getMetadata().getInstallationPath().getAsFile()
                            .toPath().relativize(j.getExecutablePath().getAsFile().toPath()).toString()));
                    p.getCompilerVersion().set("1.8.22");
                    p.getFlags().set(TimingPatch.FLAGS);
                });
            });
            project.getConfigurations().configureEach(configuration -> {
                if (!configuration.getName().startsWith("exomTiming")) {
                    configuration.getResolutionStrategy().eachDependency(dependency -> {
                        if ((dependency.getRequested().getGroup() + ":" + dependency.getRequested().getName()).equals(MODULE)) {
                            TimingPatch.checkVersion(dependency.getRequested().getVersion());
                            dependency.useVersion(TimingPatch.VERSION);
                            dependency.because("Reviewed pinned patch requires exact original Transcoder 0.10.5");
                        }
                    });
                }
            });
        });

        root.getTasks().register("verifyTranscoderTimingResolution", task -> {
            task.setGroup("verification");
            task.setDescription("Verify one patched AAR for every Android compile/runtime/test consumer.");
            task.doLast(ignored -> {
                int consumers = 0;
                Set<String> verifiedProjects = new HashSet<>();
                Set<String> verifiedClasspaths = new HashSet<>();
                Set<String> testedAppClasspaths = new HashSet<>();
                for (Project project : root.getAllprojects()) {
                    boolean declaresTranscoder = project.getConfigurations().stream().anyMatch(configuration ->
                            configuration.getAllDependencies().stream().anyMatch(dependency ->
                                    (dependency.getGroup() + ":" + dependency.getName()).equals(MODULE)));
                    if (!declaresTranscoder) continue;
                    for (Configuration configuration : project.getConfigurations()) {
                        String name = configuration.getName();
                        if (!configuration.isCanBeResolved() || !(name.endsWith("CompileClasspath")
                                || name.endsWith("RuntimeClasspath"))) continue;
                        var collection = configuration.getIncoming().artifactView(view -> {
                            // Inspect this component even when an unrelated Flutter profile artifact is not cached.
                            // A full Android build remains a separate mandatory verification.
                            view.setLenient(true);
                            view.componentFilter(id -> id instanceof ModuleComponentIdentifier module
                                    && (module.getGroup() + ":" + module.getModule()).equals(MODULE));
                            view.getAttributes().attribute(ARTIFACT_TYPE, "aar");
                        }).getArtifacts();
                        var artifacts = collection.getArtifacts();
                        if (artifacts.isEmpty() && collection.getFailures().isEmpty()
                                && name.endsWith("AndroidTestRuntimeClasspath")) {
                            // AGP removes dependencies already packaged in the tested application.
                            testedAppClasspaths.add(project.getPath() + ":" + name.replace("AndroidTest", ""));
                            root.getLogger().lifecycle("NOT_APPLICABLE timing separate test APK {}:{}; verify tested app runtime", project.getPath(), name);
                            continue;
                        }
                        if (artifacts.isEmpty()) throw new IllegalStateException("Transcoder absent/unresolved: "
                                + project.getPath() + ":" + name + "; failures=" + collection.getFailures());
                        if (artifacts.size() != 1) throw new IllegalStateException("Multiple Transcoder artifacts: " + artifacts);
                        File aar = artifacts.iterator().next().getFile();
                        try { TimingPatch.verifyPatched(aar.toPath()); }
                        catch (Exception failure) { throw new IllegalStateException("Unpatched " + project.getPath() + ":" + name, failure); }
                        root.getLogger().lifecycle("PASS timing consumer {}:{} -> {}", project.getPath(), name, aar.getName());
                        if (!collection.getFailures().isEmpty()) root.getLogger().lifecycle(
                                "NOTE {}:{} unrelated resolution failures={}; target-only check, not full graph PASS",
                                project.getPath(), name, collection.getFailures().size());
                        verifiedProjects.add(project.getPath());
                        verifiedClasspaths.add(project.getPath() + ":" + name);
                        consumers++;
                    }
                }
                if (!verifiedProjects.containsAll(Set.of(":app", ":video_compress"))) {
                    throw new IllegalStateException("Expected app/video_compress consumers absent: " + verifiedProjects);
                }
                if (!verifiedClasspaths.containsAll(testedAppClasspaths)) {
                    throw new IllegalStateException("Tested app runtime not verified: " + testedAppClasspaths);
                }
                root.getLogger().lifecycle("PASS timing Android consumers={}", consumers);
            });
        });
    }
}
