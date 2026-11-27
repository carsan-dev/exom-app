package com.exommethod.exom

import android.media.MediaCodecInfo
import kotlin.math.floor
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToLong

internal data class VideoRateRequest(val bitrate: Int, val mode: Int?)

internal object VideoBitratePolicy {
    fun sourceBitrate(trackRate: Long?, fileBytes: Long, durationUs: Long?, audioRates: List<Long?>): Double? {
        if (trackRate != null && trackRate > 0) return trackRate.toDouble()
        if (fileBytes <= 0 || durationUs == null || durationUs <= 0 || audioRates.any { it == null || it <= 0 }) return null
        val rate = fileBytes.toDouble() * 8_000_000.0 / durationUs - audioRates.sumOf { it!!.toDouble() }
        return rate.takeIf { it.isFinite() && it > 0 }
    }

    fun targetBitrate(preset: Int, width: Int, height: Int, fps: Int, sourceRate: Double?): Int {
        if (preset <= 0 || width <= 0 || height <= 0 || fps <= 0 ||
            sourceRate == null || !sourceRate.isFinite() || sourceRate <= 0) return preset
        val scaledFloor = 1_500_000.0 * width.toDouble() * height / 921_600.0 * fps / 30.0
        val qualityFloor = min(preset.toLong(), max(256_000L, scaledFloor.roundToLong()))
        return min(preset.toDouble(), max(qualityFloor.toDouble(), floor(0.90 * sourceRate))).toInt()
    }

    /** A failed capability query keeps the existing encoder mode; it never fails the compression. */
    fun cbrSupported(probe: () -> Boolean): Boolean = try {
        probe()
    } catch (_: Exception) {
        false
    }

    /**
     * Android's VBR quality floor can raise the requested rate (measured: 1,416,286 to 2,073,600 bps), so
     * CBR is requested only when the preferred encoder reports it. A null mode leaves the format untouched.
     * The requested bitrate never depends on the mode.
     */
    fun request(preset: Int, width: Int, height: Int, fps: Int, sourceRate: Double?, cbrSupported: Boolean) =
        VideoRateRequest(
            targetBitrate(preset, width, height, fps, sourceRate),
            if (cbrSupported) MediaCodecInfo.EncoderCapabilities.BITRATE_MODE_CBR else null,
        )
}
