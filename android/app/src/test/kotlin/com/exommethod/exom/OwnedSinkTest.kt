package com.exommethod.exom

import android.media.MediaCodec
import android.media.MediaFormat
import com.otaliastudios.transcoder.common.TrackStatus
import com.otaliastudios.transcoder.common.TrackType
import com.otaliastudios.transcoder.sink.DataSink
import java.nio.ByteBuffer
import org.junit.Assert.*
import org.junit.Test

class OwnedSinkTest {
    private class RecordingSink : DataSink {
        val orientations = mutableListOf<Int>()
        var releaseCount = 0
        var failRelease = false
        override fun setOrientation(orientation: Int) { orientations.add(orientation) }
        override fun setLocation(latitude: Double, longitude: Double) = Unit
        override fun setTrackStatus(type: TrackType, status: TrackStatus) = Unit
        override fun setTrackFormat(type: TrackType, format: MediaFormat) = Unit
        override fun writeTrack(type: TrackType, buffer: ByteBuffer, info: MediaCodec.BufferInfo) = Unit
        override fun stop() = Unit
        override fun release() {
            releaseCount++
            if (failRelease) error("release failed")
        }
    }

    @Test fun passthroughRestoresAllSourceRotationsAfterEngineZero() {
        for (rotation in listOf(0, 90, 180, 270)) {
            val delegate = RecordingSink()
            val sink = OwnedSink(delegate, rotation) {}
            sink.setOrientation(0)
            sink.setTrackStatus(TrackType.VIDEO, TrackStatus.PASS_THROUGH)
            assertEquals(listOf(0, rotation), delegate.orientations)
        }
    }

    @Test fun encodedVideoNeverAddsSourceRotationAgain() {
        for (rotation in listOf(90, 180, 270)) {
            val delegate = RecordingSink()
            val sink = OwnedSink(delegate, rotation) {}
            sink.setOrientation(0)
            sink.setTrackStatus(TrackType.VIDEO, TrackStatus.COMPRESSING)
            assertEquals(listOf(0, 0), delegate.orientations)
        }
    }

    @Test fun orientationAlsoSurvivesOppositeInitializationOrder() {
        val delegate = RecordingSink()
        val sink = OwnedSink(delegate, 90) {}
        sink.setTrackStatus(TrackType.VIDEO, TrackStatus.PASS_THROUGH)
        sink.setOrientation(0)
        assertEquals(listOf(90, 90), delegate.orientations)
    }

    @Test fun readyOnlyAfterAudioStatusIncludingSilentInput() {
        for (audioStatus in listOf(TrackStatus.ABSENT, TrackStatus.COMPRESSING)) {
            var readyCount = 0
            val sink = OwnedSink(RecordingSink(), 0) { readyCount++ }
            sink.setOrientation(0)
            sink.setTrackStatus(TrackType.VIDEO, TrackStatus.PASS_THROUGH)
            assertEquals(0, readyCount)
            sink.setTrackStatus(TrackType.AUDIO, audioStatus)
            assertEquals(1, readyCount)
        }
    }

    @Test fun releaseBarrierDoesNotOpenBeforeMuxerReleaseAndReleasesOnlyOnce() {
        val delegate = RecordingSink()
        val sink = OwnedSink(delegate, 0) {}
        assertEquals(1L, sink.released.count)
        sink.release()
        sink.release()
        assertEquals(0L, sink.released.count)
        assertEquals(1, delegate.releaseCount)
    }

    @Test fun failedMuxerReleaseStillUnblocksCancellationAndIsNotRetried() {
        val delegate = RecordingSink().apply { failRelease = true }
        val sink = OwnedSink(delegate, 0) {}
        assertThrows(IllegalStateException::class.java) { sink.release() }
        assertEquals(0L, sink.released.count)
        sink.release()
        assertEquals(1, delegate.releaseCount)
    }

    @Test fun releaseWaitExpiresWithoutReleasingLiveMuxer() {
        val delegate = RecordingSink()
        val sink = OwnedSink(delegate, 0) {}
        assertFalse(sink.awaitRelease(1))
        assertEquals(0, delegate.releaseCount)
        assertEquals(1L, sink.released.count)
        sink.release()
        assertTrue(sink.awaitRelease(1))
        assertEquals(1, delegate.releaseCount)
    }
}
