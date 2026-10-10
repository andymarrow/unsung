package com.andymarrow.unsung.audio

import android.content.Context
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.sqrt

/**
 * On-device vocal removal ("Quick" mode).
 *
 * Lead vocals are almost always mixed to the centre of a stereo song, so they
 * live in the mid signal (L+R) and cancel in the side signal (L-R). We keep the
 * side signal (the stereo band), and rebuild what cancellation would destroy
 * from the mid: the low end below ~160 Hz (bass, kick) and the air above
 * ~9 kHz (cymbals). Everything centred in between — the voice — is dropped.
 *
 * Limits: mono songs cannot be separated, and centred instruments (snare,
 * some synths) are softened too. The ML "Studio" mode on a server does better.
 */
object Unsinger {
    private const val BUCKETS = 160

    fun run(
        context: Context,
        source: String,
        outPath: String,
        progress: Progress,
        cancelled: () -> Boolean,
    ): Map<String, Any> {
        PcmDecoder(context, source).use { dec ->
            if (dec.channels < 2) {
                throw AudioException("This song is mono, so its vocals can't be separated on the phone.")
            }
            val instPeaks = DoubleArray(BUCKETS)
            val vocalPeaks = DoubleArray(BUCKETS)
            val estimated = max(1L, dec.estimatedFrames())
            var writer: AacWriter? = null
            var lowA: Biquad? = null
            var lowB: Biquad? = null
            var air: Biquad? = null
            var out = ShortArray(0)
            var frame = 0L
            var rate = dec.sampleRate
            var sideEnergy = 0.0
            var vocalEnergy = 0.0
            try {
                dec.decode(cancelled) { pcm, frames, r, ch ->
                    if (ch < 2) throw AudioException("This song is mono, so its vocals can't be separated on the phone.")
                    if (writer == null) {
                        rate = r
                        writer = AacWriter(outPath, r, 2)
                        lowA = Biquad.lowpass(r, 160.0)
                        lowB = Biquad.lowpass(r, 160.0)
                        air = Biquad.highpass(r, 9_000.0)
                    }
                    if (out.size < frames * 2) out = ShortArray(frames * 2)
                    for (i in 0 until frames) {
                        val l = pcm[i * ch] / 32768.0
                        val rr = pcm[i * ch + 1] / 32768.0
                        val mid = (l + rr) * 0.5
                        val side = (l - rr) * 0.5
                        val low = lowB!!.process(lowA!!.process(mid))
                        val high = air!!.process(mid)
                        val keep = low + high * 0.35
                        val oL = keep + side * 1.3
                        val oR = keep - side * 1.3
                        out[i * 2] = toShort(softLimit(oL))
                        out[i * 2 + 1] = toShort(softLimit(oR))
                        val voice = mid - low - high
                        val b = ((frame + i) * BUCKETS / estimated).toInt().coerceIn(0, BUCKETS - 1)
                        instPeaks[b] = max(instPeaks[b], max(abs(oL), abs(oR)))
                        vocalPeaks[b] = max(vocalPeaks[b], abs(voice))
                        sideEnergy += side * side
                        vocalEnergy += voice * voice
                    }
                    writer!!.write(out, frames)
                    frame += frames
                    progress.report((frame.toDouble() / estimated).coerceIn(0.0, 0.99)) {
                        mapOf("instrumentalPeaks" to instPeaks.copyOf(), "vocalPeaks" to vocalPeaks.copyOf())
                    }
                }
                writer?.finish() ?: throw AudioException("This file has no audio.")
            } finally {
                writer?.close()
            }
            progress.report(1.0)
            normalise(instPeaks)
            normalise(vocalPeaks)
            // How much stereo information there is relative to the centre. Very
            // low values mean a near-mono mix where removal will be weak.
            val stereo = sqrt(sideEnergy / (vocalEnergy + 1e-12))
            return mapOf(
                "path" to outPath,
                "durationMs" to frame * 1000 / rate,
                "instrumentalPeaks" to instPeaks,
                "vocalPeaks" to vocalPeaks,
                "stereoRatio" to stereo,
            )
        }
    }

    fun normalise(peaks: DoubleArray) {
        val top = peaks.maxOrNull() ?: 0.0
        if (top <= 0) return
        for (i in peaks.indices) peaks[i] = peaks[i] / top
    }
}

/** Normalised peak envelope of any audio file, for waveforms. */
object Peaks {
    fun of(context: Context, source: String, count: Int, cancelled: () -> Boolean): DoubleArray {
        val peaks = DoubleArray(count)
        PcmDecoder(context, source).use { dec ->
            val estimated = max(1L, dec.estimatedFrames())
            var frame = 0L
            dec.decode(cancelled) { pcm, frames, _, ch ->
                for (i in 0 until frames) {
                    var m = 0.0
                    for (c in 0 until ch) m = max(m, abs(pcm[i * ch + c] / 32768.0))
                    val b = ((frame + i) * count / estimated).toInt().coerceIn(0, count - 1)
                    if (m > peaks[b]) peaks[b] = m
                }
                frame += frames
            }
        }
        Unsinger.normalise(peaks)
        return peaks
    }
}
