package com.andymarrow.unsung.audio

import android.content.Context
import androidx.annotation.OptIn
import androidx.media3.common.C
import androidx.media3.common.audio.AudioProcessor
import androidx.media3.common.audio.SonicAudioProcessor
import androidx.media3.common.util.UnstableApi
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.pow

/** Settings for a take's mix. Effects stay editable: the raw vocal is kept. */
data class MixSettings(
    val vocalGain: Double,
    val musicGain: Double,
    val reverb: Double,
    val echo: Double,
    val offsetMs: Int,
    val semitones: Int,
    val wav: Boolean,
) {
    companion object {
        fun from(args: Map<String, Any?>) = MixSettings(
            vocalGain = (args["vocalGain"] as? Number)?.toDouble() ?: 1.0,
            musicGain = (args["musicGain"] as? Number)?.toDouble() ?: 0.85,
            reverb = (args["reverb"] as? Number)?.toDouble() ?: 0.0,
            echo = (args["echo"] as? Number)?.toDouble() ?: 0.0,
            offsetMs = (args["offsetMs"] as? Number)?.toInt() ?: 0,
            semitones = (args["semitones"] as? Number)?.toInt() ?: 0,
            wav = args["format"] == "wav",
        )
    }
}

/**
 * Renders instrumental + vocal into one stereo file, applying the key change
 * (Sonic pitch shift, tempo preserved) to the instrumental and the vocal
 * chain (high-pass, gain, echo, reverb) to the voice.
 */
@OptIn(markerClass = [UnstableApi::class])
object Mixer {
    private const val BUCKETS = 160

    fun run(
        context: Context,
        instrumental: String,
        vocal: String,
        outPath: String,
        s: MixSettings,
        progress: Progress,
        cancelled: () -> Boolean,
    ): Map<String, Any> {
        val peaks = DoubleArray(BUCKETS)
        PcmDecoder(context, instrumental).use { dec ->
            val estimated = max(1L, dec.estimatedFrames())
            var sink: PcmSink? = null
            var voice: MonoWavReader? = null
            var sonic: SonicAudioProcessor? = null
            var hp: Biquad? = null
            var echo: Echo? = null
            var revL: Reverb? = null
            var revR: Reverb? = null
            var mixed = ShortArray(0)
            var framesOut = 0L
            var framesIn = 0L
            var rate = dec.sampleRate
            var channels = 2

            fun mixAndWrite(music: ShortArray, frames: Int, ch: Int) {
                if (mixed.size < frames * 2) mixed = ShortArray(frames * 2)
                for (i in 0 until frames) {
                    val ml = music[i * ch] / 32768.0 * s.musicGain
                    val mr = (if (ch > 1) music[i * ch + 1] else music[i * ch]) / 32768.0 * s.musicGain
                    val dry = hp!!.process(voice!!.next()) * s.vocalGain
                    val wet = dry + echo!!.process(dry) * s.echo * 0.5
                    val l = ml + wet + revL!!.process(wet) * s.reverb
                    val r = mr + wet + revR!!.process(wet) * s.reverb
                    mixed[i * 2] = toShort(softLimit(l))
                    mixed[i * 2 + 1] = toShort(softLimit(r))
                    val b = ((framesOut + i) * BUCKETS / estimated).toInt().coerceIn(0, BUCKETS - 1)
                    peaks[b] = max(peaks[b], max(abs(l), abs(r)))
                }
                sink!!.write(mixed, frames)
                framesOut += frames
            }

            fun drainSonic(p: SonicAudioProcessor) {
                val out = p.output
                if (!out.hasRemaining()) return
                val sb = out.order(ByteOrder.nativeOrder()).asShortBuffer()
                val n = sb.remaining()
                val arr = ShortArray(n)
                sb.get(arr)
                out.position(out.limit())
                mixAndWrite(arr, n / channels, channels)
            }

            try {
                dec.decode(cancelled) { pcm, frames, r, ch ->
                    if (sink == null) {
                        rate = r
                        channels = ch
                        sink = if (s.wav) WavWriter(outPath, r, 2) else AacWriter(outPath, r, 2)
                        voice = MonoWavReader(vocal, r, s.offsetMs)
                        hp = Biquad.highpass(r, 90.0)
                        echo = Echo(r, 280, 0.35)
                        revL = Reverb(r, 0)
                        revR = Reverb(r, 23)
                        if (s.semitones != 0) {
                            sonic = SonicAudioProcessor().also {
                                it.setPitch(2.0.pow(s.semitones / 12.0).toFloat())
                                it.setSpeed(1f)
                                it.configure(AudioProcessor.AudioFormat(r, ch, C.ENCODING_PCM_16BIT))
                                it.flush()
                            }
                        }
                    }
                    val p = sonic
                    if (p == null) {
                        mixAndWrite(pcm, frames, ch)
                    } else {
                        val bytes = ByteBuffer.allocateDirect(frames * ch * 2).order(ByteOrder.nativeOrder())
                        bytes.asShortBuffer().put(pcm, 0, frames * ch)
                        while (bytes.hasRemaining()) {
                            p.queueInput(bytes)
                            drainSonic(p)
                        }
                    }
                    framesIn += frames
                    progress.report((framesIn.toDouble() / estimated).coerceIn(0.0, 0.99))
                }
                sonic?.let { p ->
                    p.queueEndOfStream()
                    var guard = 0
                    while (!p.isEnded && guard++ < 10_000) drainSonic(p)
                }
                sink?.finish() ?: throw AudioException("The instrumental has no audio.")
            } finally {
                sink?.close()
                voice?.close()
                sonic?.reset()
            }
            progress.report(1.0)
            Unsinger.normalise(peaks)
            return mapOf(
                "path" to outPath,
                "durationMs" to framesOut * 1000 / rate,
                "peaks" to peaks,
            )
        }
    }
}
