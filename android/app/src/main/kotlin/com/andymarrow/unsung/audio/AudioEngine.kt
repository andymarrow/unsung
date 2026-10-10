package com.andymarrow.unsung.audio

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors

/**
 * Platform channel for the native audio engine.
 *
 * Methods (unsung/audio): querySongs, artwork, unsing, mix, peaks, copyToFile, cancel.
 * Progress events (unsung/audio/progress): {taskId, progress 0..1}.
 * Heavy work runs on a background pool; results are posted on the main thread.
 */
class AudioEngine(private val context: Context, messenger: BinaryMessenger) :
    MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    private val methods = MethodChannel(messenger, "unsung/audio")
    private val events = EventChannel(messenger, "unsung/audio/progress")
    private val pool = Executors.newFixedThreadPool(2)
    private val artPool = Executors.newFixedThreadPool(2)
    private val main = Handler(Looper.getMainLooper())
    private val cancelled = ConcurrentHashMap.newKeySet<String>()
    private var sink: EventChannel.EventSink? = null

    init {
        methods.setMethodCallHandler(this)
        events.setStreamHandler(this)
    }

    fun dispose() {
        methods.setMethodCallHandler(null)
        events.setStreamHandler(null)
        pool.shutdownNow()
        artPool.shutdownNow()
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        sink = events
    }

    override fun onCancel(arguments: Any?) {
        sink = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val args = (call.arguments as? Map<*, *>)?.entries?.associate { it.key.toString() to it.value } ?: emptyMap()
        val taskId = args["taskId"] as? String ?: ""
        when (call.method) {
            "querySongs" -> run(result) { MediaLibrary.query(context) }
            "artwork" -> run(result, artPool) {
                MediaLibrary.artwork(context, args["uri"] as String, (args["size"] as? Number)?.toInt() ?: 512)
            }
            "unsing" -> run(result) {
                Unsinger.run(context, args["source"] as String, args["outPath"] as String, progress(taskId), isCancelled(taskId))
            }
            "mix" -> run(result) {
                Mixer.run(
                    context,
                    args["instrumental"] as String,
                    args["vocal"] as String,
                    args["outPath"] as String,
                    MixSettings.from(args),
                    progress(taskId),
                    isCancelled(taskId),
                )
            }
            "peaks" -> run(result) {
                Peaks.of(context, args["source"] as String, (args["count"] as? Number)?.toInt() ?: 160, isCancelled(taskId))
            }
            "copyToFile" -> run(result) {
                val uri = android.net.Uri.parse(args["source"] as String)
                val out = java.io.File(args["outPath"] as String)
                context.contentResolver.openInputStream(uri)?.use { input ->
                    out.outputStream().use { input.copyTo(it) }
                } ?: throw AudioException("Couldn't read this song file.")
                out.absolutePath
            }
            "cancel" -> {
                cancelled.add(taskId)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun isCancelled(taskId: String): () -> Boolean = { cancelled.contains(taskId) }

    private fun progress(taskId: String): Progress {
        var last = -1.0
        return Progress { p, extra ->
            if (p - last >= 0.01 || p >= 1.0) {
                last = p
                val event = HashMap<String, Any>()
                event["taskId"] = taskId
                event["progress"] = p
                extra?.invoke()?.let { event.putAll(it) }
                main.post { sink?.success(event) }
            }
        }
    }

    private fun run(
        result: MethodChannel.Result,
        executor: java.util.concurrent.ExecutorService = pool,
        work: () -> Any?,
    ) {
        executor.execute {
            try {
                val value = work()
                main.post { result.success(value) }
            } catch (e: CancelledException) {
                main.post { result.error("cancelled", "Cancelled", null) }
            } catch (e: AudioException) {
                main.post { result.error("audio", e.message, null) }
            } catch (e: SecurityException) {
                main.post { result.error("permission", "Unsung needs access to your music to do that.", null) }
            } catch (e: Exception) {
                main.post { result.error("failed", e.message ?: e.javaClass.simpleName, null) }
            }
        }
    }
}
