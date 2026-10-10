package com.andymarrow.unsung.audio

import android.content.Context
import android.media.AudioFormat
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMuxer
import android.net.Uri
import java.io.Closeable
import java.io.File
import java.io.RandomAccessFile
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.min

class AudioException(message: String) : Exception(message)

class CancelledException : Exception("Cancelled")

/**
 * Progress reporter. [extra] is only invoked when an event is actually sent,
 * so callers can attach snapshots (e.g. live peaks) without copying every chunk.
 */
fun interface Progress {
    fun report(fraction: Double, extra: (() -> Map<String, Any>)?)
}

fun Progress.report(fraction: Double) = report(fraction, null)

private const val TIMEOUT_US = 10_000L

/**
 * Streams any audio file Android can decode (mp3, m4a/aac, flac, ogg, wav…)
 * as interleaved 16-bit PCM chunks.
 */
class PcmDecoder(context: Context, source: String) : Closeable {
    private val extractor = MediaExtractor()
    private val codec: MediaCodec
    val durationUs: Long

    /** Updated from the decoder's output format before the first chunk. */
    var sampleRate: Int
        private set
    var channels: Int
        private set
    private var floatPcm = false

    init {
        try {
            if (source.startsWith("content://") || source.startsWith("file://")) {
                extractor.setDataSource(context, Uri.parse(source), null)
            } else {
                extractor.setDataSource(source)
            }
        } catch (e: Exception) {
            extractor.release()
            throw AudioException("Couldn't open this file. It may have been moved or deleted.")
        }
        var format: MediaFormat? = null
        for (i in 0 until extractor.trackCount) {
            val f = extractor.getTrackFormat(i)
            if (f.getString(MediaFormat.KEY_MIME)?.startsWith("audio/") == true) {
                extractor.selectTrack(i)
                format = f
                break
            }
        }
        if (format == null) {
            extractor.release()
            throw AudioException("This file has no audio track.")
        }
        sampleRate = format.getInteger(MediaFormat.KEY_SAMPLE_RATE)
        channels = format.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
        durationUs = if (format.containsKey(MediaFormat.KEY_DURATION)) format.getLong(MediaFormat.KEY_DURATION) else 0L
        val mime = format.getString(MediaFormat.KEY_MIME)!!
        codec = try {
            MediaCodec.createDecoderByType(mime).also {
                it.configure(format, null, null, 0)
                it.start()
            }
        } catch (e: Exception) {
            extractor.release()
            throw AudioException("This audio format isn't supported on your phone.")
        }
    }

    /** Estimated total frames, for progress. */
    fun estimatedFrames(): Long = durationUs * sampleRate / 1_000_000L

    /**
     * Decodes to the end. [onChunk] receives interleaved samples, the number of
     * frames, the sample rate and channel count.
     */
    fun decode(cancelled: () -> Boolean, onChunk: (ShortArray, Int, Int, Int) -> Unit) {
        val info = MediaCodec.BufferInfo()
        var inputDone = false
        var outputDone = false
        var scratch = ShortArray(0)
        while (!outputDone) {
            if (cancelled()) throw CancelledException()
            if (!inputDone) {
                val inIdx = codec.dequeueInputBuffer(TIMEOUT_US)
                if (inIdx >= 0) {
                    val buf = codec.getInputBuffer(inIdx)!!
                    val n = extractor.readSampleData(buf, 0)
                    if (n < 0) {
                        codec.queueInputBuffer(inIdx, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                        inputDone = true
                    } else {
                        codec.queueInputBuffer(inIdx, 0, n, extractor.sampleTime, 0)
                        extractor.advance()
                    }
                }
            }
            val outIdx = codec.dequeueOutputBuffer(info, TIMEOUT_US)
            if (outIdx == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                val f = codec.outputFormat
                sampleRate = f.getInteger(MediaFormat.KEY_SAMPLE_RATE)
                channels = f.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
                floatPcm = f.containsKey(MediaFormat.KEY_PCM_ENCODING) &&
                    f.getInteger(MediaFormat.KEY_PCM_ENCODING) == AudioFormat.ENCODING_PCM_FLOAT
            } else if (outIdx >= 0) {
                val buf = codec.getOutputBuffer(outIdx)
                if (buf != null && info.size > 0) {
                    buf.position(info.offset)
                    buf.limit(info.offset + info.size)
                    buf.order(ByteOrder.nativeOrder())
                    val samples: Int
                    if (floatPcm) {
                        val fb = buf.asFloatBuffer()
                        samples = fb.remaining()
                        if (scratch.size < samples) scratch = ShortArray(samples)
                        for (i in 0 until samples) scratch[i] = toShort(fb.get().toDouble())
                    } else {
                        val sb = buf.asShortBuffer()
                        samples = sb.remaining()
                        if (scratch.size < samples) scratch = ShortArray(samples)
                        sb.get(scratch, 0, samples)
                    }
                    val frames = samples / channels
                    if (frames > 0) onChunk(scratch, frames, sampleRate, channels)
                }
                codec.releaseOutputBuffer(outIdx, false)
                if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) outputDone = true
            }
        }
    }

    override fun close() {
        try { codec.stop() } catch (_: Exception) {}
        codec.release()
        extractor.release()
    }
}

fun toShort(x: Double): Short {
    val v = (x * 32767.0).toInt()
    return v.coerceIn(-32768, 32767).toShort()
}

/** Output sink for interleaved 16-bit PCM. */
interface PcmSink : Closeable {
    fun write(pcm: ShortArray, frames: Int)
    fun finish()
}

/** Encodes interleaved PCM to AAC-LC in an .m4a container. */
class AacWriter(
    path: String,
    private val sampleRate: Int,
    private val channels: Int,
    bitRate: Int = 192_000,
) : PcmSink {
    private val codec = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_AUDIO_AAC)
    private val muxer = MediaMuxer(path, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
    private var track = -1
    private var muxing = false
    private var framesQueued = 0L
    private val info = MediaCodec.BufferInfo()

    init {
        val f = MediaFormat.createAudioFormat(MediaFormat.MIMETYPE_AUDIO_AAC, sampleRate, channels)
        f.setInteger(MediaFormat.KEY_AAC_PROFILE, MediaCodecInfo.CodecProfileLevel.AACObjectLC)
        f.setInteger(MediaFormat.KEY_BIT_RATE, bitRate)
        f.setInteger(MediaFormat.KEY_MAX_INPUT_SIZE, 1 shl 16)
        codec.configure(f, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
        codec.start()
    }

    private fun ptsUs(): Long = framesQueued * 1_000_000L / sampleRate

    override fun write(pcm: ShortArray, frames: Int) {
        val total = frames * channels
        var offset = 0
        while (offset < total) {
            val inIdx = codec.dequeueInputBuffer(TIMEOUT_US)
            if (inIdx >= 0) {
                val buf = codec.getInputBuffer(inIdx)!!
                buf.clear()
                val capacity = (buf.remaining() / 2 / channels) * channels
                val n = min(capacity, total - offset)
                buf.order(ByteOrder.nativeOrder()).asShortBuffer().put(pcm, offset, n)
                codec.queueInputBuffer(inIdx, 0, n * 2, ptsUs(), 0)
                offset += n
                framesQueued += (n / channels).toLong()
            }
            drain(false)
        }
    }

    override fun finish() {
        var queued = false
        while (!queued) {
            val inIdx = codec.dequeueInputBuffer(TIMEOUT_US)
            if (inIdx >= 0) {
                codec.queueInputBuffer(inIdx, 0, 0, ptsUs(), MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                queued = true
            } else {
                drain(false)
            }
        }
        drain(true)
    }

    private fun drain(untilEos: Boolean) {
        var idle = 0
        while (true) {
            val idx = codec.dequeueOutputBuffer(info, TIMEOUT_US)
            if (idx == MediaCodec.INFO_TRY_AGAIN_LATER) {
                if (!untilEos || ++idle > 500) return
            } else if (idx == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                track = muxer.addTrack(codec.outputFormat)
                muxer.start()
                muxing = true
            } else if (idx >= 0) {
                idle = 0
                val buf = codec.getOutputBuffer(idx)
                if (info.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG != 0) info.size = 0
                if (buf != null && info.size > 0 && muxing) {
                    buf.position(info.offset)
                    buf.limit(info.offset + info.size)
                    muxer.writeSampleData(track, buf, info)
                }
                codec.releaseOutputBuffer(idx, false)
                if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) return
            }
        }
    }

    override fun close() {
        try { codec.stop() } catch (_: Exception) {}
        codec.release()
        try { if (muxing) muxer.stop() } catch (_: Exception) {}
        muxer.release()
    }
}

/** Streams interleaved PCM16 to a WAV file. Fast; used for previews. */
class WavWriter(path: String, private val sampleRate: Int, private val channels: Int) : PcmSink {
    private val file = RandomAccessFile(File(path).also { it.delete() }, "rw")
    private var dataBytes = 0L
    private var bytes = ByteArray(0)

    init {
        file.write(ByteArray(44))
    }

    override fun write(pcm: ShortArray, frames: Int) {
        val n = frames * channels
        if (bytes.size < n * 2) bytes = ByteArray(n * 2)
        ByteBuffer.wrap(bytes).order(ByteOrder.LITTLE_ENDIAN).asShortBuffer().put(pcm, 0, n)
        file.write(bytes, 0, n * 2)
        dataBytes += n * 2
    }

    override fun finish() {
        val h = ByteBuffer.allocate(44).order(ByteOrder.LITTLE_ENDIAN)
        h.put("RIFF".toByteArray()).putInt((36 + dataBytes).toInt()).put("WAVE".toByteArray())
        h.put("fmt ".toByteArray()).putInt(16).putShort(1).putShort(channels.toShort())
        h.putInt(sampleRate).putInt(sampleRate * channels * 2).putShort((channels * 2).toShort()).putShort(16)
        h.put("data".toByteArray()).putInt(dataBytes.toInt())
        file.seek(0)
        file.write(h.array())
    }

    override fun close() = file.close()
}

/**
 * Reads a PCM16 WAV (as written by the app's recorder) frame by frame as mono
 * doubles, resampled to [targetRate] with linear interpolation.
 */
class MonoWavReader(path: String, private val targetRate: Int, startOffsetMs: Int) : Closeable {
    private val file = RandomAccessFile(path, "r")
    private val rate: Int
    private val channels: Int
    private val dataStart: Long
    private val dataEnd: Long
    private var pos = 0.0
    private val step: Double
    private val buffer = ByteArray(1 shl 15)
    private var bufStartFrame = -1L
    private var bufFrames = 0

    init {
        val header = ByteArray(12)
        file.readFully(header)
        if (String(header, 0, 4) != "RIFF" || String(header, 8, 4) != "WAVE") {
            throw AudioException("The vocal recording is damaged.")
        }
        var r = 44_100
        var ch = 1
        var start = 44L
        var size = 0L
        while (file.filePointer < file.length()) {
            val id = ByteArray(4)
            file.readFully(id)
            val len = Integer.reverseBytes(file.readInt()).toLong() and 0xffffffffL
            val name = String(id)
            if (name == "fmt ") {
                val fmt = ByteArray(len.toInt())
                file.readFully(fmt)
                val b = ByteBuffer.wrap(fmt).order(ByteOrder.LITTLE_ENDIAN)
                b.short
                ch = b.short.toInt()
                r = b.int
            } else if (name == "data") {
                start = file.filePointer
                size = min(len, file.length() - start)
                break
            } else {
                file.seek(file.filePointer + len)
            }
        }
        rate = r
        channels = ch
        dataStart = start
        dataEnd = start + size
        step = rate.toDouble() / targetRate
        // Positive offset skips the start of the vocal (recording latency);
        // negative offset delays it.
        pos = startOffsetMs * rate / 1000.0
    }

    private val totalFrames: Long get() = (dataEnd - dataStart) / (2L * channels)

    private fun frameAt(index: Long): Double {
        if (index < 0 || index >= totalFrames) return 0.0
        if (index < bufStartFrame || index >= bufStartFrame + bufFrames) {
            bufStartFrame = index
            file.seek(dataStart + index * 2L * channels)
            val want = min(buffer.size.toLong(), (totalFrames - index) * 2L * channels).toInt()
            file.readFully(buffer, 0, want)
            bufFrames = want / (2 * channels)
        }
        val base = ((index - bufStartFrame) * 2 * channels).toInt()
        var sum = 0.0
        for (c in 0 until channels) {
            val lo = buffer[base + 2 * c].toInt() and 0xff
            val hi = buffer[base + 2 * c + 1].toInt()
            sum += ((hi shl 8) or lo).toShort() / 32768.0
        }
        return sum / channels
    }

    fun next(): Double {
        val i = Math.floor(pos).toLong()
        val frac = pos - i
        val v = frameAt(i) * (1 - frac) + frameAt(i + 1) * frac
        pos += step
        return v
    }

    override fun close() = file.close()
}
