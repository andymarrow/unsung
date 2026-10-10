package com.andymarrow.unsung.audio

import android.content.ContentUris
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.provider.MediaStore
import java.io.ByteArrayOutputStream

/** Reads the device music library from MediaStore. */
object MediaLibrary {
    private const val MIN_DURATION_MS = 30_000

    fun query(context: Context): List<Map<String, Any?>> {
        val collection = MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
        val projection = arrayOf(
            MediaStore.Audio.Media._ID,
            MediaStore.Audio.Media.TITLE,
            MediaStore.Audio.Media.ARTIST,
            MediaStore.Audio.Media.ALBUM,
            MediaStore.Audio.Media.DURATION,
            MediaStore.Audio.Media.MIME_TYPE,
            MediaStore.Audio.Media.SIZE,
            MediaStore.Audio.Media.DATE_ADDED,
        )
        val selection = "${MediaStore.Audio.Media.IS_MUSIC} != 0 AND ${MediaStore.Audio.Media.DURATION} >= ?"
        val songs = mutableListOf<Map<String, Any?>>()
        context.contentResolver.query(
            collection,
            projection,
            selection,
            arrayOf(MIN_DURATION_MS.toString()),
            "${MediaStore.Audio.Media.TITLE} COLLATE NOCASE ASC",
        )?.use { c ->
            val id = c.getColumnIndexOrThrow(MediaStore.Audio.Media._ID)
            val title = c.getColumnIndexOrThrow(MediaStore.Audio.Media.TITLE)
            val artist = c.getColumnIndexOrThrow(MediaStore.Audio.Media.ARTIST)
            val album = c.getColumnIndexOrThrow(MediaStore.Audio.Media.ALBUM)
            val duration = c.getColumnIndexOrThrow(MediaStore.Audio.Media.DURATION)
            val mime = c.getColumnIndexOrThrow(MediaStore.Audio.Media.MIME_TYPE)
            val size = c.getColumnIndexOrThrow(MediaStore.Audio.Media.SIZE)
            val added = c.getColumnIndexOrThrow(MediaStore.Audio.Media.DATE_ADDED)
            while (c.moveToNext()) {
                val songId = c.getLong(id)
                val rawArtist = c.getString(artist)
                songs.add(
                    mapOf(
                        "id" to songId.toString(),
                        "title" to (c.getString(title) ?: "Untitled"),
                        "artist" to if (rawArtist == null || rawArtist == "<unknown>") null else rawArtist,
                        "album" to c.getString(album),
                        "durationMs" to c.getLong(duration),
                        "mime" to c.getString(mime),
                        "size" to c.getLong(size),
                        "addedAt" to c.getLong(added) * 1000L,
                        "uri" to ContentUris.withAppendedId(collection, songId).toString(),
                    ),
                )
            }
        }
        return songs
    }

    /** Embedded cover art as JPEG, scaled to about [size] px, or null. */
    fun artwork(context: Context, uri: String, size: Int): ByteArray? {
        val retriever = MediaMetadataRetriever()
        return try {
            retriever.setDataSource(context, Uri.parse(uri))
            val raw = retriever.embeddedPicture ?: return null
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            BitmapFactory.decodeByteArray(raw, 0, raw.size, bounds)
            var sample = 1
            while (bounds.outWidth / (sample * 2) >= size && bounds.outHeight / (sample * 2) >= size) sample *= 2
            val bmp = BitmapFactory.decodeByteArray(raw, 0, raw.size, BitmapFactory.Options().apply { inSampleSize = sample })
                ?: return null
            val out = ByteArrayOutputStream()
            bmp.compress(Bitmap.CompressFormat.JPEG, 85, out)
            bmp.recycle()
            out.toByteArray()
        } catch (_: Exception) {
            null
        } finally {
            try { retriever.release() } catch (_: Exception) {}
        }
    }
}
