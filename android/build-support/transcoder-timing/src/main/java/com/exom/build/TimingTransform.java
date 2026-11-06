package com.exom.build;

import org.gradle.api.artifacts.transform.CacheableTransform;
import org.gradle.api.artifacts.transform.InputArtifact;
import org.gradle.api.artifacts.transform.TransformAction;
import org.gradle.api.artifacts.transform.TransformOutputs;
import org.gradle.api.artifacts.transform.TransformParameters;
import org.gradle.api.file.ConfigurableFileCollection;
import org.gradle.api.file.DirectoryProperty;
import org.gradle.api.file.FileSystemLocation;
import org.gradle.api.file.RegularFileProperty;
import org.gradle.api.provider.ListProperty;
import org.gradle.api.provider.Provider;
import org.gradle.api.provider.Property;
import org.gradle.api.tasks.Classpath;
import org.gradle.api.tasks.Input;
import org.gradle.api.tasks.InputDirectory;
import org.gradle.api.tasks.InputFile;
import org.gradle.api.tasks.PathSensitive;
import org.gradle.api.tasks.PathSensitivity;

import java.nio.file.Path;

@CacheableTransform
public abstract class TimingTransform implements TransformAction<TimingTransform.Parameters> {
    public interface Parameters extends TransformParameters {
        @InputFile @PathSensitive(PathSensitivity.NONE) RegularFileProperty getSource();
        @InputFile @PathSensitive(PathSensitivity.NONE) RegularFileProperty getPipelineSource();
        @Classpath ConfigurableFileCollection getCompilerClasspath();
        @Classpath ConfigurableFileCollection getStdlib();
        // Include the entire selected JDK, not just its java launcher executable.
        @InputDirectory @PathSensitive(PathSensitivity.RELATIVE) DirectoryProperty getJavaHome();
        @Input Property<String> getJavaIdentity();
        @Input Property<String> getJavaExecutable();
        @Input Property<String> getCompilerVersion();
        @Input ListProperty<String> getFlags();
    }

    @InputArtifact @PathSensitive(PathSensitivity.NONE)
    public abstract Provider<FileSystemLocation> getInputArtifact();

    @Override public void transform(TransformOutputs outputs) {
        try {
            Parameters p = getParameters();
            if (!p.getCompilerVersion().get().equals("1.8.22")) {
                throw new IllegalStateException("Unexpected Kotlin compiler version");
            }
            Path output = outputs.file("transcoder-0.10.5-exom-timing.aar").toPath();
            TimingPatch.build(getInputArtifact().get().getAsFile().toPath(), p.getSource().get().getAsFile().toPath(),
                    p.getPipelineSource().get().getAsFile().toPath(),
                    p.getCompilerClasspath().getAsPath(), p.getStdlib().getSingleFile().toPath(),
                    p.getJavaHome().get().getAsFile().toPath().resolve(p.getJavaExecutable().get()),
                    p.getFlags().get(), output.getParent().resolve("compiler-work"), output);
        } catch (Exception failure) {
            throw new IllegalStateException("Pinned Transcoder timing patch failed", failure);
        }
    }
}
