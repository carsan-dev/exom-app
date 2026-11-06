package com.exommethod.exom

import org.junit.Assert.*
import org.junit.Test

class VideoBitratePolicyTest {
    @Test fun confirmedFixtureUsesSourceCeiling() {
        assertEquals(1_411_168, VideoBitratePolicy.targetBitrate(3_096_576, 1280, 720, 24, 1_567_965.0))
    }

    @Test fun qualityFloorScalesWithOutputAndNeverExceedsPreset() {
        assertEquals(1_500_000, VideoBitratePolicy.targetBitrate(4_000_000, 1280, 720, 30, 100_000.0))
        assertEquals(256_000, VideoBitratePolicy.targetBitrate(4_000_000, 320, 180, 24, 100_000.0))
        assertEquals(200_000, VideoBitratePolicy.targetBitrate(200_000, 1280, 720, 30, 100_000.0))
    }

    @Test fun highSourceRateDoesNotRaisePreset() {
        assertEquals(3_096_576, VideoBitratePolicy.targetBitrate(3_096_576, 1280, 720, 24, 50_000_000.0))
    }

    @Test fun unknownOrMalformedMetadataPreservesPreset() {
        for (rate in listOf(null, 0.0, -1.0, Double.NaN, Double.POSITIVE_INFINITY)) {
            assertEquals(3_000_000, VideoBitratePolicy.targetBitrate(3_000_000, 1280, 720, 30, rate))
        }
        for (dimensions in listOf(Triple(0, 720, 30), Triple(1280, -1, 30), Triple(1280, 720, 0))) {
            assertEquals(3_000_000, VideoBitratePolicy.targetBitrate(3_000_000, dimensions.first, dimensions.second, dimensions.third, 1_000_000.0))
        }
    }

    @Test fun arithmeticDoesNotOverflowLargeDimensions() {
        assertEquals(Int.MAX_VALUE, VideoBitratePolicy.targetBitrate(Int.MAX_VALUE, Int.MAX_VALUE, Int.MAX_VALUE, Int.MAX_VALUE, Double.MAX_VALUE))
    }

    @Test fun trackBitratePreferredOverContainerEstimate() {
        assertEquals(1_000_000.0, VideoBitratePolicy.sourceBitrate(1_000_000, 100, 1L, listOf(null))!!, 0.01)
    }

    @Test fun fallbackSubtractsAllKnownAudioRatesAndSupportsSilentVideo() {
        assertEquals(700_000.0, VideoBitratePolicy.sourceBitrate(null, 1_000_000, 10_000_000L, listOf(100_000L))!!, 0.01)
        assertEquals(800_000.0, VideoBitratePolicy.sourceBitrate(null, 1_000_000, 10_000_000L, emptyList())!!, 0.01)
        assertEquals(600_000.0, VideoBitratePolicy.sourceBitrate(null, 1_000_000, 10_000_000L, listOf(100_000L, 100_000L))!!, 0.01)
    }

    @Test fun invalidFallbackIsUnknownNeverZero() {
        assertNull(VideoBitratePolicy.sourceBitrate(null, 100, null, emptyList()))
        assertNull(VideoBitratePolicy.sourceBitrate(null, 100, 0L, emptyList()))
        assertNull(VideoBitratePolicy.sourceBitrate(null, 0, 10L, emptyList()))
        assertNull(VideoBitratePolicy.sourceBitrate(null, 100, 10L, listOf(null)))
        assertNull(VideoBitratePolicy.sourceBitrate(null, 100, 10L, listOf(0L)))
        assertNull(VideoBitratePolicy.sourceBitrate(null, 100, 10_000_000L, listOf(1_000_000L)))
        assertNull(VideoBitratePolicy.sourceBitrate(-1, -1, -1L, emptyList()))
    }

    // Android-measured source30 rate: 6,261,565 B * 8 / 30 s - 96,099 bps audio.
    private val source30Rate = VideoBitratePolicy.sourceBitrate(null, 6_261_565, 30_000_000L, listOf(96_099L))

    @Test fun cbrRequestedWhenPreferredEncoderSupportsIt() {
        val request = VideoBitratePolicy.request(3_096_576, 1280, 720, 24, source30Rate, cbrSupported = true)
        // MediaCodecInfo.EncoderCapabilities.BITRATE_MODE_CBR is 2; CBR_FD (3) must not be requested.
        assertEquals(VideoRateRequest(1_416_286, 2), request)
    }

    @Test fun unsupportedCbrKeepsExistingModeAndSameBitrate() {
        val request = VideoBitratePolicy.request(3_096_576, 1280, 720, 24, source30Rate, cbrSupported = false)
        assertEquals(VideoRateRequest(1_416_286, null), request)
    }

    @Test fun modeSelectionNeverChangesRequestedBitrate() {
        val cases = listOf(
            listOf(3_096_576, 1280, 720, 24) to source30Rate,
            listOf(4_000_000, 1280, 720, 30) to 100_000.0,
            listOf(3_096_576, 1280, 720, 24) to 50_000_000.0,
            listOf(3_000_000, 1280, 720, 30) to null,
        )
        for ((format, rate) in cases) {
            val (preset, width, height, fps) = format
            val expected = VideoBitratePolicy.targetBitrate(preset, width, height, fps, rate)
            for (cbr in listOf(true, false)) {
                assertEquals(expected, VideoBitratePolicy.request(preset, width, height, fps, rate, cbr).bitrate)
            }
        }
    }

    @Test fun capabilityProbeReportsSupportOnlyWhenEncoderDoes() {
        assertTrue(VideoBitratePolicy.cbrSupported { true })
        assertFalse(VideoBitratePolicy.cbrSupported { false })
    }

    @Test fun capabilityProbeFailureFallsBackToExistingMode() {
        assertFalse(VideoBitratePolicy.cbrSupported { throw IllegalStateException("codec unavailable") })
        assertFalse(VideoBitratePolicy.cbrSupported { throw java.io.IOException("no encoder") })
    }
}
