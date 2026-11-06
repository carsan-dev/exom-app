package com.exommethod.exom

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import android.media.MediaCodec
import android.media.MediaFormat
import com.otaliastudios.transcoder.common.TrackStatus
import com.otaliastudios.transcoder.common.TrackType
import com.otaliastudios.transcoder.sink.DataSink
import java.io.File
import java.nio.ByteBuffer
import java.util.concurrent.Callable
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.FutureTask
import java.util.concurrent.TimeUnit
import org.junit.Assert.*
import org.junit.Test

class VideoCompressionDeadlineTest {
    private class Clock {
        var now = 0L
        val posts = java.util.concurrent.ConcurrentLinkedQueue<() -> Unit>()
        val timers = mutableListOf<Pair<Long, () -> Unit>>()
        val post: (() -> Unit) -> Unit = { posts.add(it); Unit }
        val schedule: (Long, () -> Unit) -> (() -> Unit) = { delay, task ->
            val entry = Pair(now + delay, task)
            timers.add(entry)
            val cancel: () -> Unit = { timers.remove(entry); Unit }
            cancel
        }
        fun flush() { while (true) (posts.poll() ?: break).invoke() }
        fun advance(millis: Long) {
            val end = now + millis
            while (true) {
                val entry = timers.filter { it.first <= end }.minByOrNull { it.first } ?: break
                now = entry.first
                timers.remove(entry)
                entry.second()
                flush()
            }
            now = end
            flush()
        }
    }
    private class Reply : MethodChannel.Result {
        val values = mutableListOf<Any?>()
        override fun success(result: Any?) { values.add(result) }
        override fun error(code: String, message: String?, details: Any?) { values.add(code) }
        override fun notImplemented() { values.add("notImplemented") }
    }
    private fun field(operation: Any, name: String, value: Any?) {
        operation.javaClass.getDeclaredField(name).apply { isAccessible = true }.set(operation, value)
    }
    private fun outcome(operation: Any) = operation.javaClass.getDeclaredField("outcome")
        .apply { isAccessible = true }.get(operation) as NativeCompressionOutcome
    private fun plugin(clock: Clock, worker: java.util.concurrent.ExecutorService,
        task: (String, Any) -> Boolean): VideoCompressionPlugin {
        val constructor = VideoCompressionPlugin::class.java.declaredConstructors.single { it.parameterCount == 5 }
        return constructor.newInstance(clock.post, clock.schedule, { true }, worker, task) as VideoCompressionPlugin
    }
    private fun call(plugin: VideoCompressionPlugin, path: String = "source.mov") = Reply().also {
        plugin.onMethodCall(MethodCall("compress", mapOf("path" to path)), it)
    }
    private fun waitFor(clock: Clock, seconds: Long = 3, condition: () -> Boolean) {
        val end = System.nanoTime() + TimeUnit.SECONDS.toNanos(seconds)
        while (!condition() && System.nanoTime() < end) {
            clock.flush()
            Thread.yield()
        }
        clock.flush()
        assertTrue("Worker did not finish", condition())
    }

    private fun stopWorker(clock: Clock, worker: java.util.concurrent.ExecutorService) {
        worker.shutdownNow()
        assertTrue(worker.awaitTermination(3, TimeUnit.SECONDS))
        clock.flush()
    }

    private class EmptySink : DataSink {
        override fun setOrientation(orientation: Int) = Unit
        override fun setLocation(latitude: Double, longitude: Double) = Unit
        override fun setTrackStatus(type: TrackType, status: TrackStatus) = Unit
        override fun setTrackFormat(type: TrackType, format: MediaFormat) = Unit
        override fun writeTrack(type: TrackType, buffer: ByteBuffer, info: MediaCodec.BufferInfo) = Unit
        override fun stop() = Unit
        override fun release() = Unit
    }

    private fun finish(plugin: VideoCompressionPlugin, operation: Any) {
        plugin.javaClass.getDeclaredMethod("finish", operation.javaClass)
            .apply { isAccessible = true }.invoke(plugin, operation)
    }

    private fun nativeTask(engine: Callable<Void>, onExit: Runnable) =
        NativeTranscodeTask(engine, onExit)

    private fun awaitIgnoringInterrupts(latch: CountDownLatch) {
        while (true) {
            try { latch.await(); return } catch (_: InterruptedException) { }
        }
    }

    @Test fun sinkReleaseDoesNotAdmitReplacementBeforeRemainingCodecCleanup() {
        cleanupInterleaving(lateSink = false)
    }

    @Test fun lateFullExitRetiresAfterTerminalCallbackAndReleaseGraceAlreadyRan() {
        cleanupInterleaving(lateSink = true)
    }

    @Test fun newPluginCannotReplaceDetachedOwnerBeforeNativeCleanupExits() {
        cleanupInterleaving(lateSink = false, newInstance = true)
    }

    @Test fun startupFailureWithBlockedFallbackReleaseKeepsProcessOwnerUntilRelease() {
        val clock = Clock()
        val worker = Executors.newSingleThreadExecutor()
        val retryWorker = Executors.newSingleThreadExecutor()
        val native = Executors.newSingleThreadExecutor()
        val cleanupEntered = CountDownLatch(1)
        val releaseCleanup = CountDownLatch(1)
        val directory = java.nio.file.Files.createTempDirectory("exom-startup-cleanup-").toFile()
        val source = File(directory, "source.mov").apply { writeBytes(byteArrayOf(1, 2, 3)) }
        val output = File(directory, "owned.mp4").apply { writeBytes(byteArrayOf(4)) }
        val releases = java.util.concurrent.atomic.AtomicInteger()
        val sink = OwnedSink(object : DataSink by EmptySink() {
            override fun release() {
                cleanupEntered.countDown()
                awaitIgnoringInterrupts(releaseCleanup)
                releases.incrementAndGet()
            }
        }, 0) {}
        var operation: Any? = null
        lateinit var plugin: VideoCompressionPlugin
        plugin = plugin(clock, worker) { _, current ->
            operation = current
            field(current, "engineLaunched", true)
            field(current, "engineReady", true)
            field(current, "output", output)
            val task = NativeTranscodeTask(Callable<Void> {
                throw IllegalStateException("engine constructor failed before upstream cleanup")
            }, Runnable { sink.release() }, Runnable { clock.post { finish(plugin, current) } })
            field(current, "future", task)
            native.execute(task)
            task.get()
            false
        }
        val contender = plugin(clock, retryWorker) { _, _ -> false }
        try {
            val reply = call(plugin, source.path)
            assertTrue(cleanupEntered.await(3, TimeUnit.SECONDS))
            clock.advance(305000)
            assertEquals(listOf("compression_timeout"), reply.values)
            waitFor(clock, seconds = 8) {
                operation!!.javaClass.getDeclaredField("workerFinished")
                    .apply { isAccessible = true }.getBoolean(operation)
            }
            assertEquals(listOf("compression_timeout"), call(contender).values)
            assertTrue(output.exists())
            assertEquals(0, releases.get())
            releaseCleanup.countDown()
            native.shutdown()
            assertTrue(native.awaitTermination(3, TimeUnit.SECONDS))
            waitFor(clock) {
                plugin.javaClass.getDeclaredField("active").apply { isAccessible = true }.get(plugin) == null
            }
            assertEquals(1, releases.get())
            assertFalse(output.exists())
            assertEquals(listOf("compression_timeout"), reply.values)
            assertArrayEquals(byteArrayOf(1, 2, 3), source.readBytes())
        } finally {
            releaseCleanup.countDown()
            native.shutdownNow()
            native.awaitTermination(3, TimeUnit.SECONDS)
            stopWorker(clock, worker)
            stopWorker(clock, retryWorker)
            directory.deleteRecursively()
        }
    }

    @Test fun rejectedPreparationSubmissionRepliesOnceAndReleasesAdmission() {
        val clock = Clock()
        val rejected = Executors.newSingleThreadExecutor().apply { shutdown() }
        val retryWorker = Executors.newSingleThreadExecutor()
        val plugin = plugin(clock, rejected) { _, _ -> error("Rejected worker ran") }
        val retryPlugin = plugin(clock, retryWorker) { _, _ -> false }
        try {
            val reply = call(plugin)
            clock.flush()
            assertEquals(listOf("compression_failed"), reply.values)
            clock.advance(305000)
            assertEquals(listOf("compression_failed"), reply.values)
            val retry = call(retryPlugin)
            waitFor(clock) { retry.values.isNotEmpty() }
            assertEquals(listOf("compression_failed"), retry.values)
        } finally {
            rejected.shutdownNow()
            retryWorker.shutdownNow()
            retryWorker.awaitTermination(3, TimeUnit.SECONDS)
            clock.flush()
        }
    }

    private fun cleanupInterleaving(lateSink: Boolean, newInstance: Boolean = false) {
        val clock = Clock()
        val worker = Executors.newSingleThreadExecutor()
        val replacementWorker = Executors.newSingleThreadExecutor()
        val native = Executors.newSingleThreadExecutor()
        val started = CountDownLatch(1)
        val sinkGate = CountDownLatch(if (lateSink) 1 else 0)
        val codecGate = CountDownLatch(1)
        val sinkReleased = CountDownLatch(1)
        val launches = java.util.concurrent.atomic.AtomicInteger()
        val directory = java.nio.file.Files.createTempDirectory("exom-native-cleanup-").toFile()
        val source = File(directory, "source.mov").apply { writeBytes(byteArrayOf(1, 2, 3)) }
        val output = File(directory, "owned.mp4").apply { writeBytes(byteArrayOf(4)) }
        var operation: Any? = null
        lateinit var plugin: VideoCompressionPlugin
        plugin = plugin(clock, worker) { _, current ->
            if (launches.incrementAndGet() != 1) false else {
                operation = current
                val sink = OwnedSink(EmptySink(), 0) {}
                field(current, "engineLaunched", true)
                field(current, "engineReady", true)
                field(current, "output", output)
                val task = nativeTask(Callable {
                    started.countDown()
                    try {
                        CountDownLatch(1).await()
                    } catch (_: InterruptedException) {
                        // Transcoder dispatches terminal before cleanup, not after it.
                        clock.post {
                            outcome(current).onTranscodeCanceled()
                            finish(plugin, current)
                        }
                    }
                    awaitIgnoringInterrupts(sinkGate)
                    sink.release()
                    sinkReleased.countDown()
                    awaitIgnoringInterrupts(codecGate)
                    null
                }, Runnable { clock.post { finish(plugin, current) } })
                field(current, "future", task)
                native.execute(task)
                task.get()
                false
            }
        }
        val contender = if (newInstance) plugin(clock, replacementWorker) { _, _ ->
            launches.incrementAndGet()
            false
        } else plugin
        try {
            val reply = call(plugin, source.path)
            assertTrue(started.await(3, TimeUnit.SECONDS))
            clock.advance(305000)
            assertEquals(listOf("compression_timeout"), reply.values)
            if (newInstance) {
                plugin.javaClass.methods.single { it.name.startsWith("detach$") }.invoke(plugin)
                clock.flush()
            }
            waitFor(clock, seconds = 8) {
                operation!!.javaClass.getDeclaredField("workerFinished")
                    .apply { isAccessible = true }.getBoolean(operation)
            }
            if (!lateSink) {
                assertTrue(sinkReleased.await(3, TimeUnit.SECONDS))
                assertEquals("A released sink is not a released codec", listOf("compression_timeout"), call(contender).values)
            } else {
                sinkGate.countDown()
                assertTrue(sinkReleased.await(3, TimeUnit.SECONDS))
            }
            assertTrue("Output still belongs to the cleaning-up engine", output.exists())
            assertEquals(1, launches.get())
            val maintenance = Reply()
            contender.onMethodCall(MethodCall("acquireMaintenance", null), maintenance)
            assertEquals("No maintenance before full native task exit", listOf(null), maintenance.values)
            codecGate.countDown()
            native.shutdown()
            assertTrue(native.awaitTermination(3, TimeUnit.SECONDS))
            waitFor(clock) {
                plugin.javaClass.getDeclaredField("active").apply { isAccessible = true }.get(plugin) == null
            }
            assertFalse(output.exists())
            val retry = call(contender)
            waitFor(clock) { retry.values.isNotEmpty() }
            assertEquals(listOf("compression_failed"), retry.values)
            assertEquals(2, launches.get())
            assertEquals(listOf("compression_timeout"), reply.values)
            assertArrayEquals(byteArrayOf(1, 2, 3), source.readBytes())
        } finally {
            sinkGate.countDown()
            codecGate.countDown()
            native.shutdownNow()
            worker.shutdownNow()
            replacementWorker.shutdownNow()
            native.awaitTermination(3, TimeUnit.SECONDS)
            worker.awaitTermination(3, TimeUnit.SECONDS)
            replacementWorker.awaitTermination(3, TimeUnit.SECONDS)
            clock.flush()
            directory.deleteRecursively()
        }
    }

    @Test fun deadlineCoversBlockedSetupAndQuarantinesUntilWorkerActuallyExits() {
        val clock = Clock()
        val worker = Executors.newSingleThreadExecutor()
        val started = CountDownLatch(1)
        val release = CountDownLatch(1)
        val plugin = plugin(clock, worker) { _, _ -> started.countDown(); release.await(); false }
        try {
            val reply = call(plugin)
            assertTrue(started.await(3, TimeUnit.SECONDS))
            clock.advance(299999)
            assertEquals(emptyList<Any?>(), reply.values)
            clock.advance(5000)
            assertEquals(emptyList<Any?>(), reply.values)
            clock.advance(1)
            assertEquals(listOf("compression_timeout"), reply.values)
            assertEquals(listOf("compression_timeout"), call(plugin).values)
            val contender = plugin(clock, worker) { _, _ -> false }
            val whileActive = Reply()
            contender.onMethodCall(MethodCall("acquireMaintenance", null), whileActive)
            assertEquals(listOf(null), whileActive.values)
            release.countDown()
            worker.shutdown()
            assertTrue(worker.awaitTermination(3, TimeUnit.SECONDS))
            clock.flush()
            assertEquals(listOf("compression_timeout"), reply.values)
            val idle = Reply()
            contender.onMethodCall(MethodCall("acquireMaintenance", null), idle)
            val token = idle.values.single()
            assertTrue(token is String)
            contender.onMethodCall(
                MethodCall("releasePreparationLease", mapOf("token" to token)),
                Reply(),
            )
        } finally { release.countDown(); stopWorker(clock, worker) }
    }

    @Test fun ignoredCancellationAndLateSuccessNeverReplyTwiceOrDeleteSource() {
        val clock = Clock()
        val worker = Executors.newSingleThreadExecutor()
        val started = CountDownLatch(1)
        val release = CountDownLatch(1)
        val directory = java.nio.file.Files.createTempDirectory("exom-native-deadline-").toFile()
        val source = File(directory, "source.mov").apply { writeBytes(byteArrayOf(1, 2, 3)) }
        val output = File(directory, "owned.mp4").apply { writeBytes(byteArrayOf(4)) }
        var cancellations = 0
        val future = object : FutureTask<Void>({ null }) {
            override fun cancel(interrupt: Boolean): Boolean { cancellations++; return false }
        }
        val plugin = plugin(clock, worker) { _, operation ->
            field(operation, "engineReady", true)
            field(operation, "future", future)
            field(operation, "output", output)
            started.countDown()
            release.await()
            outcome(operation).onTranscodeCompleted(0)
            true
        }
        try {
            val reply = call(plugin, source.path)
            assertTrue(started.await(3, TimeUnit.SECONDS))
            clock.advance(305000)
            assertEquals(listOf("compression_timeout"), reply.values)
            assertEquals(1, cancellations)
            assertTrue(output.exists())
            release.countDown()
            worker.shutdown()
            assertTrue(worker.awaitTermination(3, TimeUnit.SECONDS))
            clock.flush()
            assertEquals(listOf("compression_timeout"), reply.values)
            assertFalse(output.exists())
            assertArrayEquals(byteArrayOf(1, 2, 3), source.readBytes())
        } finally { release.countDown(); stopWorker(clock, worker); directory.deleteRecursively() }
    }

    @Test fun stuckReleaseCannotBlockDeadlineReplyOrOtherQueuedCalls() {
        val clock = Clock()
        val worker = Executors.newSingleThreadExecutor()
        val inRelease = CountDownLatch(1)
        val release = CountDownLatch(1)
        val plugin = plugin(clock, worker) { _, operation ->
            outcome(operation).onTranscodeCompleted(0)
            inRelease.countDown()
            release.await()
            true
        }
        try {
            val reply = call(plugin)
            assertTrue(inRelease.await(3, TimeUnit.SECONDS))
            clock.advance(305000)
            assertEquals(listOf("compression_timeout"), reply.values)
            assertEquals(listOf("compression_timeout"), call(plugin).values)
        } finally { release.countDown(); stopWorker(clock, worker) }
    }

    @Test fun completionBeforeDeadlineKeepsAcceptedOutputAndRepliesOnce() {
        val clock = Clock()
        val worker = Executors.newSingleThreadExecutor()
        val output = java.nio.file.Files.createTempFile("exom-accepted-", ".mp4").toFile()
            .apply { writeBytes(byteArrayOf(4)) }
        var completedOperation: Any? = null
        val plugin = plugin(clock, worker) { _, operation ->
            completedOperation = operation
            field(operation, "output", output)
            outcome(operation).onTranscodeCompleted(0)
            true
        }
        try {
            val reply = call(plugin)
            waitFor(clock) { reply.values.isNotEmpty() }
            assertEquals(listOf(output.path), reply.values)
            clock.advance(305000)
            assertEquals(listOf(output.path), reply.values)
            plugin.javaClass.getDeclaredMethod("finish", completedOperation!!.javaClass).apply {
                isAccessible = true
            }.invoke(plugin, completedOperation)
            assertTrue(output.exists())
        } finally { stopWorker(clock, worker); output.delete() }
    }

    @Test fun detachVersusDeadlineAndLateFinishHasSingleReply() {
        for (timeoutFirst in listOf(false, true)) {
            val clock = Clock()
            val worker = Executors.newSingleThreadExecutor()
            val started = CountDownLatch(1)
            val release = CountDownLatch(1)
            val plugin = plugin(clock, worker) { _, _ -> started.countDown(); release.await(); false }
            try {
                val reply = call(plugin)
                assertTrue(started.await(3, TimeUnit.SECONDS))
                if (timeoutFirst) clock.advance(305000)
                plugin.javaClass.methods.single { it.name.startsWith("detach$") }.invoke(plugin)
                clock.flush()
                clock.advance(305000)
                release.countDown()
                worker.shutdown()
                assertTrue(worker.awaitTermination(3, TimeUnit.SECONDS))
                clock.flush()
                assertEquals(listOf(if (timeoutFirst) "compression_timeout" else "compression_cancelled"), reply.values)
            } finally { release.countDown(); stopWorker(clock, worker) }
        }
    }
}
