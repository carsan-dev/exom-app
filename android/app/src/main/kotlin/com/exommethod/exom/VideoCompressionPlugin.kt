package com.exommethod.exom

import android.content.Context
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.system.ErrnoException
import android.system.Os
import android.system.OsConstants
import com.otaliastudios.transcoder.Transcoder
import com.otaliastudios.transcoder.TranscoderListener
import com.otaliastudios.transcoder.common.TrackStatus
import com.otaliastudios.transcoder.common.TrackType
import com.otaliastudios.transcoder.sink.DataSink
import com.otaliastudios.transcoder.sink.DefaultDataSink
import com.otaliastudios.transcoder.source.UriDataSource
import com.otaliastudios.transcoder.strategy.DefaultAudioStrategy
import com.otaliastudios.transcoder.strategy.DefaultVideoStrategy
import com.otaliastudios.transcoder.strategy.TrackStrategy
import com.otaliastudios.transcoder.validator.WriteAlwaysValidator
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.UUID
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.ExecutorService
import java.util.concurrent.TimeUnit
import java.util.concurrent.Future
import java.util.concurrent.RejectedExecutionException
import java.util.concurrent.atomic.AtomicBoolean

class VideoCompressionPlugin internal constructor(
    private val testPost: ((() -> Unit) -> Unit)? = null,
    private val testSchedule: ((Long, () -> Unit) -> (() -> Unit))? = null,
    private val testOnMain: (() -> Boolean)? = null,
    private val testWorker: ExecutorService? = null,
    private val testCompress: ((String, Operation) -> Boolean)? = null,
) : FlutterPlugin, MethodChannel.MethodCallHandler {
    companion object {
        // Operational limits, not input limits: retain slow inputs for retry.
        internal const val DEADLINE_MS = 5 * 60 * 1000L
        internal const val RELEASE_GRACE_MS = 5 * 1000L
        private val admissionLock = Any()
        private var nativeOwner: Operation? = null
        private var preparationLease: PreparationLease? = null
        private const val PREPARATION_ROOT = "feedback_preparation_v1"
        private val addressScope = Regex("[a-f0-9]{64}")
        private val addressId = Regex("[a-f0-9]{32}")
        private val preparationLeaves = setOf("compressed.mp4", "prepared.mp4", "prepared.jpg")
    }

    private val main by lazy { Handler(Looper.getMainLooper()) }
    private val lock = admissionLock
    private var context: Context? = null
    private var channel: MethodChannel? = null
    private var worker: ExecutorService? = testWorker
    private var active: Operation? = null
    internal var testPreparationFiles: Pair<File, (File) -> PreparationEntry>? = null

    internal enum class PreparationEntry { MISSING, DIRECTORY, SINGLE_FILE, OTHER }
    private class PreparationLease(
        val owner: VideoCompressionPlugin,
        val token: String,
        val maintenance: Boolean,
    ) {
        var address: List<String>? = null
        var kind: String? = null
        var opened = false
    }

    private class PreparationError(val code: String) : Exception()

    internal class Operation(var result: MethodChannel.Result?) {
        val outcome = NativeCompressionOutcome()
        @Volatile var cancelled = false
        @Volatile var timedOut = false
        @Volatile var engineLaunched = false
        var workerFinished = false
        var preparedOutput = false
        var retired = false
        var cancelDeadline: (() -> Unit)? = null
        var cancelGrace: (() -> Unit)? = null
        var engineReady = false
        var future: Future<Void>? = null
        var output: File? = null
        var reservedOutput: File? = null
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        worker = Executors.newSingleThreadExecutor()
        channel = MethodChannel(binding.binaryMessenger, "com.exommethod.exom/video_compression")
            .also { it.setMethodCallHandler(this) }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) = detach()

    internal fun detach() {
        channel?.setMethodCallHandler(null)
        channel = null
        context = null
        val operation = synchronized(lock) {
            active?.also {
                it.cancelled = true
                // Before engine initialization, cancellation is observed by the sink instead.
                if (it.engineReady) it.future?.cancel(true)
            }
        }
        if (operation != null) post { reply(operation, "compression_cancelled") }
        worker?.shutdown()
        worker = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (!(testOnMain?.invoke() ?: (Looper.myLooper() == main.looper))) {
            post { onMethodCall(call, result) }
            return
        }
        if (call.method != "compress") {
            handlePreparation(call, result)
            return
        }
        val appContext = context
        val executor = worker
        val path = call.argument<String>("path")
        if ((appContext == null && testCompress == null) || executor == null) {
            result.error("compression_cancelled", "Video compression unavailable", null)
            return
        }
        if (path.isNullOrBlank()) {
            result.error("compression_invalid_input", "Video input required", null)
            return
        }
        val token = call.argument<String>("token")
        val owned = call.argument<Boolean>("ownedOutput") == true
        if (appContext != null && runCatching {
                val root = File(appContext.filesDir.canonicalFile, PREPARATION_ROOT)
                val source = File(path)
                isInside(source.absoluteFile.normalize(), root) ||
                    isInside(source.absoluteFile.parentFile!!.canonicalFile, root) ||
                    isInside(source.canonicalFile, root)
            }.getOrDefault(true)) {
            result.error("compression_invalid_input", "Invalid video input", null)
            return
        }
        val operation = synchronized(lock) {
            val lease = preparationLease
            val allowed = if (lease == null) token == null else
                token == lease.token && lease.owner === this && !lease.maintenance
            val reserved = if (owned && allowed && lease?.opened == true && lease.kind == "video") {
                File(preparationDirectory(lease.address!!), "compressed.mp4")
            } else null
            if (nativeOwner != null || !allowed || (owned && reserved == null)) null
            else Operation(result).also {
                it.reservedOutput = reserved
                active = it
                nativeOwner = it
            }
        }
        if (operation == null) {
            val code = synchronized(lock) {
                if (nativeOwner?.timedOut == true) "compression_timeout" else "compression_busy"
            }
            result.error(code, "Video compression already running", null)
            return
        }
        // Independent of the worker: setup, codecs and muxer release can all hang.
        operation.cancelDeadline = after(DEADLINE_MS) {
            synchronized(lock) {
                if (active !== operation || operation.retired) return@after
                operation.timedOut = true
                operation.cancelled = true
                if (operation.engineReady) operation.future?.cancel(true)
            }
            operation.cancelGrace = after(RELEASE_GRACE_MS) {
                reply(operation, "compression_timeout")
            }
        }
        try {
            executor.execute { compress(appContext, path, operation) }
        } catch (_: RejectedExecutionException) {
            post {
                operation.workerFinished = true
                finish(operation)
            }
        }
    }

    private fun handlePreparation(call: MethodCall, result: MethodChannel.Result) {
        try {
            val value: Any? = synchronized(lock) {
                when (call.method) {
                    "acquirePreparation", "acquireMaintenance" -> {
                        if (context == null && testCompress == null && testPreparationFiles == null) {
                            throw PreparationError("compression_cancelled")
                        }
                        val maintenance = call.method == "acquireMaintenance"
                        if (nativeOwner != null || preparationLease != null) {
                            if (maintenance) null else throw PreparationError(
                                if (nativeOwner?.timedOut == true) "compression_timeout" else "compression_busy",
                            )
                        } else UUID.randomUUID().toString().also {
                            preparationLease = PreparationLease(this, it, maintenance)
                        }
                    }
                    "releasePreparationLease" -> {
                        requireLease(call)
                        preparationLease = null
                        null
                    }
                    "planPreparation" -> {
                        val lease = requireLease(call, maintenance = false)
                        check(!lease.opened && lease.address == null && nativeOwner == null)
                        val kind = call.argument<String>("kind")
                        require(kind == "video" || kind == "image")
                        val address = preparationAddress(call)
                        check(preparationEntry(address) == PreparationEntry.MISSING)
                        lease.address = address
                        lease.kind = kind
                        preparationDirectory(address).path
                    }
                    "openPreparation" -> {
                        val lease = requireLease(call, maintenance = false)
                        check(!lease.opened && nativeOwner == null)
                        val address = requireNotNull(lease.address)
                        check(preparationEntry(address) == PreparationEntry.MISSING)
                        for (end in 1..address.size) {
                            val directory = preparationDirectory(address.take(end))
                            val entry = fileEntry(directory)
                            if (entry == PreparationEntry.MISSING) check(directory.mkdir())
                            else check(end < address.size && entry == PreparationEntry.DIRECTORY)
                        }
                        lease.opened = true
                        null
                    }
                    "deletePreparationFile" -> {
                        requireLease(call, maintenance = true)
                        check(nativeOwner == null)
                        val leaf = call.argument<String>("leaf")
                        require(leaf != null && leaf in preparationLeaves)
                        val address = preparationAddress(call) + leaf
                        when (preparationEntry(address)) {
                            PreparationEntry.MISSING -> true
                            PreparationEntry.SINGLE_FILE -> preparationDirectory(address).delete()
                            else -> false
                        }
                    }
                    else -> {
                        result.notImplemented()
                        return
                    }
                }
            }
            result.success(value)
        } catch (error: PreparationError) {
            result.error(error.code, "Feedback preparation unavailable", null)
        } catch (_: Exception) {
            result.error("compression_failed", "Feedback preparation unavailable", null)
        }
    }

    private fun requireLease(call: MethodCall, maintenance: Boolean? = null): PreparationLease {
        val lease = preparationLease
        if (lease == null || lease.owner !== this || call.argument<String>("token") != lease.token ||
            (maintenance != null && lease.maintenance != maintenance)) {
            throw PreparationError("compression_busy")
        }
        return lease
    }

    private fun preparationAddress(call: MethodCall): List<String> {
        val scope = requireNotNull(call.argument<String>("scope"))
        val operation = requireNotNull(call.argument<String>("operation"))
        val attempt = requireNotNull(call.argument<String>("attempt"))
        require(addressScope.matches(scope) && addressId.matches(operation) && addressId.matches(attempt))
        return listOf(PREPARATION_ROOT, scope, operation, attempt)
    }

    private fun preparationDirectory(address: List<String>): File {
        val support = testPreparationFiles?.first ?: requireNotNull(context).filesDir
        return address.fold(support.canonicalFile) { directory, part -> File(directory, part) }
    }

    private fun isInside(file: File, root: File) =
        file == root || file.path.startsWith(root.path + File.separator)

    private fun fileEntry(file: File): PreparationEntry {
        testPreparationFiles?.let { return it.second(file) }
        val status = try {
            Os.lstat(file.path)
        } catch (error: ErrnoException) {
            if (error.errno == OsConstants.ENOENT) return PreparationEntry.MISSING
            throw error
        }
        return when {
            OsConstants.S_ISDIR(status.st_mode) -> PreparationEntry.DIRECTORY
            OsConstants.S_ISREG(status.st_mode) && status.st_nlink == 1L -> PreparationEntry.SINGLE_FILE
            else -> PreparationEntry.OTHER
        }
    }

    // Only this plugin and the lease holder write under these app-private
    // parents. Never follow a substituted parent or unlink a shared inode.
    private fun preparationEntry(address: List<String>): PreparationEntry {
        for (end in 1..address.size) {
            val file = preparationDirectory(address.take(end))
            val entry = fileEntry(file)
            if (entry == PreparationEntry.MISSING) return entry
            if (file.canonicalFile != file) return PreparationEntry.OTHER
            if (end == address.size) return entry
            if (entry != PreparationEntry.DIRECTORY) return PreparationEntry.OTHER
        }
        return PreparationEntry.OTHER
    }

    private fun compress(appContext: Context?, path: String, operation: Operation) {
        var sink: OwnedSink? = null
        var success = false
        try {
            if (testCompress != null) {
                success = testCompress.invoke(path, operation)
            } else {
                requireNotNull(appContext)
                val source = File(path)
                require(source.isFile && source.length() > 0)
                val metadata = readMetadata(source)
                val cbrSupported = preferredAvcEncoderSupportsCbr()
                if (operation.cancelled) return
                val output = operation.reservedOutput ?: run {
                    val directory = File(appContext.cacheDir, "video_compression")
                    check(directory.isDirectory || directory.mkdirs())
                    File(directory, "${UUID.randomUUID()}.mp4")
                }
                check(output.createNewFile())
                operation.output = output
                sink = OwnedSink(DefaultDataSink(output.path), metadata.rotation) {
                    synchronized(lock) {
                        operation.engineReady = true
                        if (operation.cancelled) Thread.currentThread().interrupt()
                    }
                }
                val options = Transcoder.into(sink)
                    .addDataSource(UriDataSource(appContext, Uri.fromFile(source)))
                    .setVideoTrackStrategy(SourceAwareVideoStrategy(metadata.sourceRate, cbrSupported))
                    .setAudioTrackStrategy(DefaultAudioStrategy.builder()
                        .channels(DefaultAudioStrategy.CHANNELS_AS_INPUT)
                        .sampleRate(DefaultAudioStrategy.SAMPLE_RATE_AS_INPUT).build())
                    .setValidator(WriteAlwaysValidator())
                    .setListenerHandler(main)
                    .setListener(operation.outcome)
                    .build()
                val future = NativeTranscodeTask(options) { post { finish(operation) } }
                synchronized(lock) {
                    operation.engineLaunched = true
                    operation.future = future
                }
                future.enqueue()
                synchronized(lock) {
                    if (operation.cancelled && operation.engineReady) future.cancel(true)
                }
                future.get()
                success = !operation.cancelled && output.isFile && output.length() > 0
            }
        } catch (_: Exception) {
            // Return stable codes; never expose source paths or return unverified originals.
        } finally {
            if (operation.engineLaunched) {
                // Only task exit covers cleanup after the terminal callback and sink release.
                val task = operation.future as? NativeTranscodeTask
                if (runCatching { task?.awaitExit(RELEASE_GRACE_MS) == true }
                        .getOrDefault(false).not()) success = false
                if (task?.hasExited() == true && !task.engineEntered() &&
                    runCatching { sink?.release() }.isFailure) success = false
            } else if (runCatching { sink?.release() }.isFailure) success = false
            val completed = success
            post {
                operation.preparedOutput = completed
                operation.workerFinished = true
                finish(operation)
            }
        }
    }

    private fun finish(operation: Operation) {
        if (operation.retired || !operation.workerFinished) return
        if (operation.engineLaunched &&
            (operation.future as? NativeTranscodeTask)?.hasExited() != true) return
        operation.retired = true
        operation.cancelDeadline?.invoke()
        operation.cancelGrace?.invoke()
        val current = synchronized(lock) {
            (active === operation).also {
                if (it) active = null
                if (nativeOwner === operation) nativeOwner = null
            }
        }
        if (operation.outcome.accepts(operation.preparedOutput) && current && !operation.cancelled) {
            val result = operation.result
            operation.result = null
            result?.success(operation.output!!.path)
        } else {
            if (operation.reservedOutput == null) operation.output?.delete()
            reply(operation, when {
                operation.timedOut -> "compression_timeout"
                operation.cancelled || operation.outcome.cancelled -> "compression_cancelled"
                else -> "compression_failed"
            })
        }
    }

    private fun after(millis: Long, task: () -> Unit): () -> Unit {
        val schedule = testSchedule
        if (schedule != null) return schedule(millis, task)
        val runnable = Runnable(task)
        main.postDelayed(runnable, millis)
        return { main.removeCallbacks(runnable) }
    }

    private fun post(task: () -> Unit) {
        val dispatch = testPost
        if (dispatch != null) dispatch(task) else main.post(task)
    }

    private fun reply(operation: Operation, code: String) {
        val result = operation.result
        operation.result = null
        result?.error(code, "Video compression did not complete", null)
    }

    private data class Metadata(val sourceRate: Double?, val rotation: Int)

    // Same selection as Transcoder 0.10.5 (createEncoderByType on the output MIME); the component chosen
    // is not known beforehand, so query that exact component and release it before transcoding starts.
    private fun preferredAvcEncoderSupportsCbr(): Boolean = VideoBitratePolicy.cbrSupported {
        val codec = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_VIDEO_AVC)
        try {
            codec.codecInfo.getCapabilitiesForType(MediaFormat.MIMETYPE_VIDEO_AVC).encoderCapabilities
                ?.isBitrateModeSupported(MediaCodecInfo.EncoderCapabilities.BITRATE_MODE_CBR) == true
        } finally {
            codec.release()
        }
    }

    private fun readMetadata(source: File): Metadata {
        val extractor = MediaExtractor()
        try {
            extractor.setDataSource(source.path)
            var video: MediaFormat? = null
            val audioRates = mutableListOf<Long?>()
            for (index in 0 until extractor.trackCount) {
                val format = extractor.getTrackFormat(index)
                val mime = format.getString(MediaFormat.KEY_MIME).orEmpty()
                if (mime.startsWith("video/") && video == null) video = format
                if (mime.startsWith("audio/")) audioRates.add(format.positiveLong(MediaFormat.KEY_BIT_RATE))
            }
            val format = requireNotNull(video)
            var duration = format.positiveLong(MediaFormat.KEY_DURATION)
            var rotation = runCatching { format.getInteger(MediaFormat.KEY_ROTATION) }.getOrNull()
            if (duration == null || rotation == null) {
                val retriever = MediaMetadataRetriever()
                try {
                    runCatching {
                        retriever.setDataSource(source.path)
                        if (duration == null) duration = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
                            ?.toLongOrNull()?.takeIf { it > 0 && it <= Long.MAX_VALUE / 1000 }?.times(1000)
                        if (rotation == null) rotation = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)?.toIntOrNull()
                    }
                } finally {
                    retriever.release()
                }
            }
            require(rotation == null || rotation in listOf(0, 90, 180, 270))
            return Metadata(VideoBitratePolicy.sourceBitrate(
                format.positiveLong(MediaFormat.KEY_BIT_RATE), source.length(), duration, audioRates,
            ), rotation ?: 0)
        } finally {
            extractor.release()
        }
    }
}

internal class NativeCompressionOutcome : TranscoderListener {
    private var terminal = false
    private var successful = false
    var cancelled = false
        private set

    fun accepts(preparedOutput: Boolean) = successful && preparedOutput

    private fun finish(successful: Boolean = false, cancelled: Boolean = false) {
        if (terminal) return
        terminal = true
        this.successful = successful
        this.cancelled = cancelled
    }

    override fun onTranscodeProgress(progress: Double) = Unit
    override fun onTranscodeCompleted(successCode: Int) = finish(successCode == Transcoder.SUCCESS_TRANSCODED)
    override fun onTranscodeCanceled() = finish(cancelled = true)
    override fun onTranscodeFailed(exception: Throwable) = finish()
}

internal class SourceAwareVideoStrategy(
    private val sourceRate: Double?,
    private val cbrSupported: Boolean,
) : TrackStrategy {
    private val delegate = DefaultVideoStrategy.atMost(720, 1280).build()

    override fun createOutputFormat(inputs: MutableList<MediaFormat>, output: MediaFormat): TrackStatus {
        val status = delegate.createOutputFormat(inputs, output)
        if (status == TrackStatus.COMPRESSING && inputs.size == 1 &&
            inputs.single().getString(MediaFormat.KEY_MIME) == "video/avc") {
            val preset = output.positiveLong(MediaFormat.KEY_BIT_RATE)?.takeIf { it <= Int.MAX_VALUE }?.toInt()
            if (preset != null) {
                val request = VideoBitratePolicy.request(
                    preset,
                    output.positiveLong(MediaFormat.KEY_WIDTH)?.toInt() ?: 0,
                    output.positiveLong(MediaFormat.KEY_HEIGHT)?.toInt() ?: 0,
                    output.positiveLong(MediaFormat.KEY_FRAME_RATE)?.toInt() ?: 0,
                    sourceRate,
                    cbrSupported,
                )
                output.setInteger(MediaFormat.KEY_BIT_RATE, request.bitrate)
                request.mode?.let { output.setInteger(MediaFormat.KEY_BITRATE_MODE, it) }
            }
        }
        return status
    }
}

internal class OwnedSink(
    private val delegate: DataSink,
    private val sourceRotation: Int,
    private val onReady: () -> Unit,
) : DataSink by delegate {
    private val didRelease = AtomicBoolean()
    val released = CountDownLatch(1)
    private var videoStatus: TrackStatus? = null

    fun awaitRelease(millis: Long) = released.await(millis, TimeUnit.MILLISECONDS)

    override fun setOrientation(orientation: Int) {
        delegate.setOrientation(if (videoStatus == TrackStatus.PASS_THROUGH) sourceRotation else 0)
    }

    override fun setTrackStatus(type: TrackType, status: TrackStatus) {
        if (type == TrackType.VIDEO) {
            videoStatus = status
            // 0.10.5 sets orientation before track status, both before muxer start.
            setOrientation(0)
        }
        delegate.setTrackStatus(type, status)
        if (type == TrackType.AUDIO) onReady()
    }

    override fun release() {
        if (didRelease.compareAndSet(false, true)) {
            try {
                delegate.release()
            } finally {
                released.countDown()
            }
        }
    }
}

private fun MediaFormat.positiveLong(key: String): Long? =
    (runCatching { getLong(key) }.getOrNull()
        ?: runCatching { getInteger(key).toLong() }.getOrNull())?.takeIf { it > 0 }
