plugins {
    `java-gradle-plugin`
}

java {
    toolchain.languageVersion.set(JavaLanguageVersion.of(17))
}

gradlePlugin {
    plugins {
        create("transcoderTiming") {
            id = "com.exom.transcoder-timing"
            implementationClass = "com.exom.build.TranscoderTimingPlugin"
        }
    }
}

tasks.register<JavaExec>("verifyTimingPatchGuards") {
    dependsOn(tasks.testClasses)
    classpath = sourceSets.test.get().runtimeClasspath
    mainClass.set("com.exom.build.TimingPatchGuardsTest")
}

repositories {
    google()
    mavenCentral()
}

val hostCompiler by configurations.creating {
    isTransitive = false
}
val hostOriginal by configurations.creating {
    isTransitive = false
}
dependencies {
    listOf(
        "org.jetbrains.kotlin:kotlin-compiler-embeddable:1.8.22",
        "org.jetbrains.kotlin:kotlin-stdlib:1.8.22",
        "org.jetbrains.kotlin:kotlin-reflect:1.6.10",
        "org.jetbrains.intellij.deps:trove4j:1.0.20200330",
        "org.jetbrains:annotations:13.0",
    ).forEach { add(hostCompiler.name, it) }
    add(hostOriginal.name, "com.otaliastudios:transcoder:0.10.5")
}

tasks.register<JavaExec>("verifyTimingPatch") {
    dependsOn("verifyTimingPatchGuards", tasks.testClasses)
    classpath = sourceSets.test.get().runtimeClasspath
    mainClass.set("com.exom.build.TimingPatchRegressionTest")
    val launcher = javaToolchains.launcherFor { languageVersion.set(JavaLanguageVersion.of(17)) }
    javaLauncher.set(launcher)
    doFirst {
        args(hostOriginal.singleFile.absolutePath, hostCompiler.asPath,
            hostCompiler.files.single { it.name == "kotlin-stdlib-1.8.22.jar" }.absolutePath,
            launcher.get().executablePath.asFile.absolutePath, projectDir.absolutePath)
    }
}
