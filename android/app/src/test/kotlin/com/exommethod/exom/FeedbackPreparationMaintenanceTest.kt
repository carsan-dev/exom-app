package com.exommethod.exom

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.nio.file.Files
import java.nio.file.AccessDeniedException
import java.nio.file.LinkOption.NOFOLLOW_LINKS
import java.nio.file.NoSuchFileException
import java.nio.file.attribute.BasicFileAttributes
import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

class FeedbackPreparationMaintenanceTest {
    @get:Rule val temporary = TemporaryFolder()

    private val operation = "1".repeat(32)
    private val attempt = "2".repeat(32)
    private val scope = "a".repeat(64)
    private val address = mapOf("scope" to scope, "operation" to operation, "attempt" to attempt)
    private val relative = "feedback_preparation_v1/$scope/$operation/$attempt"
    private var ambiguous: File? = null
    private var unstatable: File? = null

    private fun stat(file: File): VideoCompressionPlugin.PreparationEntry {
        if (file == unstatable) throw AccessDeniedException(file.path)
        if (file == ambiguous) return VideoCompressionPlugin.PreparationEntry.OTHER
        val attributes = try {
            Files.readAttributes(file.toPath(), BasicFileAttributes::class.java, NOFOLLOW_LINKS)
        } catch (_: NoSuchFileException) {
            return VideoCompressionPlugin.PreparationEntry.MISSING
        }
        return when {
            attributes.isDirectory -> VideoCompressionPlugin.PreparationEntry.DIRECTORY
            attributes.isRegularFile -> VideoCompressionPlugin.PreparationEntry.SINGLE_FILE
            else -> VideoCompressionPlugin.PreparationEntry.OTHER
        }
    }

    private fun plugin() = VideoCompressionPlugin(testOnMain = { true }).also {
        val directory = temporary.root.canonicalFile
        assertEquals(File(requireNotNull(System.getProperty("java.io.tmpdir"))).canonicalFile, directory.parentFile)
        it.testPreparationFiles = directory to ::stat
    }

    private fun call(
        plugin: VideoCompressionPlugin,
        method: String,
        arguments: Map<String, Any> = emptyMap(),
    ): Any? {
        var result: Any? = Unit
        plugin.onMethodCall(MethodCall(method, arguments), object : MethodChannel.Result {
            override fun success(value: Any?) { result = value }
            override fun error(code: String, message: String?, details: Any?) { result = code }
            override fun notImplemented() { result = "notImplemented" }
        })
        assertNotEquals(Unit, result)
        return result
    }

    @Test fun staleEngineLeaseExcludesNewEngineAndWrongTokenCannotReleaseIt() {
        val first = plugin()
        val next = plugin()
        val token = call(first, "acquirePreparation") as String
        val args = mapOf("token" to token)
        try {
            first.detach()
            assertNull(call(next, "acquireMaintenance"))
            assertEquals("compression_busy", call(next, "acquirePreparation"))
            assertEquals("compression_busy", call(next, "releasePreparationLease", args))
            assertEquals("compression_busy", call(first, "releasePreparationLease", mapOf("token" to "wrong")))
            assertNull(call(next, "acquireMaintenance"))
        } finally {
            // Test teardown: production detach does not perform this release.
            assertNull(call(first, "releasePreparationLease", args))
        }
        val maintenance = call(next, "acquireMaintenance") as String
        try {
            assertEquals("compression_busy", call(first, "acquirePreparation"))
            assertEquals("compression_busy", call(first, "releasePreparationLease", args))
            assertEquals("compression_busy", call(first, "openPreparation", args))
            assertNull(call(first, "acquireMaintenance"))
        } finally {
            assertNull(call(next, "releasePreparationLease", mapOf("token" to maintenance)))
        }
    }

    @Test fun planCreatesNothingAndMaintenanceDeletesOnlyValidatedSingleLeaves() {
        val plugin = plugin()
        val token = call(plugin, "acquirePreparation") as String
        val directory = File(temporary.root.canonicalFile, relative)
        val expected = address + mapOf("token" to token, "kind" to "video")
        val leaf = File(directory, "compressed.mp4")
        try {
            assertEquals(directory.path, call(plugin, "planPreparation", expected))
            assertFalse(directory.exists())
            assertNull(call(plugin, "openPreparation", mapOf("token" to token)))
            leaf.writeText("synthetic")
            assertEquals("compression_busy", call(plugin, "deletePreparationFile",
                expected + ("leaf" to leaf.name)))
            assertTrue(leaf.isFile)
        } finally {
            assertNull(call(plugin, "releasePreparationLease", mapOf("token" to token)))
        }
        val maintenance = call(plugin, "acquireMaintenance") as String
        try {
            val args = address + mapOf("token" to maintenance, "leaf" to leaf.name)
            val source = File(temporary.root, "source.mp4").apply { writeText("keep") }
            assertEquals("compression_failed", call(plugin, "deletePreparationFile",
                args + ("leaf" to "../../../../source.mp4")))
            assertEquals("compression_failed", call(plugin, "deletePreparationFile",
                args + ("attempt" to "..")))
            ambiguous = directory // No-follow stat reports a substituted parent link.
            assertEquals(false, call(plugin, "deletePreparationFile", args))
            assertTrue(leaf.isFile)
            ambiguous = leaf // Native stat rejects a shared inode as non-disposable.
            assertEquals(false, call(plugin, "deletePreparationFile", args))
            assertTrue(leaf.isFile)
            ambiguous = null
            unstatable = leaf
            assertEquals("compression_failed", call(plugin, "deletePreparationFile", args))
            assertTrue(leaf.isFile)
            unstatable = null
            assertEquals(true, call(plugin, "deletePreparationFile", args))
            assertEquals(true, call(plugin, "deletePreparationFile", args))
            assertTrue(directory.isDirectory)
            assertEquals("keep", source.readText())
        } finally {
            assertNull(call(plugin, "releasePreparationLease", mapOf("token" to maintenance)))
        }
    }
}
