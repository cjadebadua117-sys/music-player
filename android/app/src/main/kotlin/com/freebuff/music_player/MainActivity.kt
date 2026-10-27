package com.freebuff.music_player

import android.Manifest
import android.content.ContentUris
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.util.Size
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.concurrent.Executors
import kotlin.math.roundToInt

/**
 * Hands the device's music library to Dart.
 *
 * Extending AudioServiceActivity keeps the Flutter UI and the background audio
 * service attached to the same engine, which is what just_audio_background needs.
 *
 * The app asks for the audio permission once and then reads MediaStore; songs are
 * played straight from their content:// URIs, so nothing is copied and the
 * library stays in step with whatever is actually on the phone.
 */
class MainActivity : AudioServiceActivity() {

    private companion object {
        const val CHANNEL = "music_player/media"
        const val PERMISSION_REQUEST = 4711
        const val NOTIFICATION_REQUEST = 4712
    }

    private var pendingPermissionResult: MethodChannel.Result? = null
    private var pendingNotificationResult: MethodChannel.Result? = null
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    /** READ_MEDIA_AUDIO on Android 13+, the storage permission before that. */
    private val audioPermission: String
        get() = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            Manifest.permission.READ_MEDIA_AUDIO
        } else {
            Manifest.permission.READ_EXTERNAL_STORAGE
        }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        requestFastestRefreshRate()
    }

    /**
     * Asks the window for the display's fastest mode (90/120 Hz) instead of
     * letting the system pick the 60 Hz default. Android still lets the user's
     * Display settings cap this, but on phones that expose a high mode to apps
     * the UI now animates at that rate. Flutter renders one frame per vsync, so
     * this is the hardware ceiling - there is no 999 fps mode.
     */
    private fun requestFastestRefreshRate() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
        try {
            @Suppress("DEPRECATION")
            val screen = windowManager.defaultDisplay ?: return
            val fastest = screen.supportedModes.maxByOrNull { it.refreshRate }
                ?: return
            if (fastest.refreshRate <= 60.5f) return
            window.attributes = window.attributes.apply {
                preferredDisplayModeId = fastest.modeId
                preferredRefreshRate = fastest.refreshRate
            }
        } catch (_: Exception) {
            // A window manager that refuses the request simply stays at 60 Hz.
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasPermission" -> result.success(isGranted())
                    "requestPermission" -> requestPermission(result)
                    "hasNotificationPermission" -> result.success(
                        hasNotificationPermission(),
                    )
                    "requestNotificationPermission" -> requestNotificationPermission(result)
                    "scanSongs" -> scanSongs(result)
                    "albumArt" -> albumArt(
                        call.argument("albumId"),
                        call.argument("trackId"),
                        result,
                    )
                    "fileArtwork" -> fileArtwork(call.argument("path"), result)
                    "lyrics" -> lyrics(call.argument("trackId"), result)
                    "fileLyrics" -> fileLyrics(call.argument("path"), result)
                    else -> result.notImplemented()
                }
            }
    }

    private fun isGranted(): Boolean =
        checkSelfPermission(audioPermission) == PackageManager.PERMISSION_GRANTED

    private fun requestPermission(result: MethodChannel.Result) {
        if (isGranted()) {
            result.success(true)
            return
        }
        if (pendingPermissionResult != null) {
            result.error("busy", "Another permission request is already open", null)
            return
        }
        pendingPermissionResult = result
        requestPermissions(arrayOf(audioPermission), PERMISSION_REQUEST)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        val granted =
            grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
        when (requestCode) {
            PERMISSION_REQUEST -> {
                pendingPermissionResult?.success(granted)
                pendingPermissionResult = null
            }
            NOTIFICATION_REQUEST -> {
                pendingNotificationResult?.success(granted)
                pendingNotificationResult = null
            }
        }
    }

    /**
     * Whether the phone lets us post the playback notification. Android 13
     * made that a runtime permission; media notifications are exempt from the
     * permission dialog, but the playback service still needs to be able to
     * post its notification on phones that ignore the exemption.
     */
    private fun hasNotificationPermission(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED

    private fun requestNotificationPermission(result: MethodChannel.Result) {
        if (hasNotificationPermission()) {
            result.success(true)
            return
        }
        if (pendingNotificationResult != null) {
            result.error("busy", "Another permission request is already open", null)
            return
        }
        pendingNotificationResult = result
        requestPermissions(
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            NOTIFICATION_REQUEST,
        )
    }

    private fun scanSongs(result: MethodChannel.Result) {
        if (!isGranted()) {
            result.success(emptyList<Map<String, Any?>>())
            return
        }
        // Reading the library is disk work: keep it off the main thread and
        // answer on the main thread, which is where channel replies must go.
        worker.execute {
            val songs = try {
                querySongs()
            } catch (error: Exception) {
                main.post {
                    result.error("scan_failed", "Could not read the music library", error.message)
                }
                return@execute
            }
            main.post { result.success(songs) }
        }
    }

    private fun querySongs(): List<Map<String, Any?>> {
        val projection = arrayOf(
            MediaStore.Audio.Media._ID,
            MediaStore.Audio.Media.TITLE,
            MediaStore.Audio.Media.ARTIST,
            MediaStore.Audio.Media.ALBUM,
            MediaStore.Audio.Media.ALBUM_ID,
            MediaStore.Audio.Media.DURATION,
            @Suppress("DEPRECATION") MediaStore.Audio.Media.DATA,
        )
        val songs = mutableListOf<Map<String, Any?>>()
        contentResolver.query(
            MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
            projection,
            "${MediaStore.Audio.Media.IS_MUSIC} != 0",
            null,
            "${MediaStore.Audio.Media.TITLE} ASC",
        )?.use { cursor ->
            val idColumn = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media._ID)
            val titleColumn = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.TITLE)
            val artistColumn = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.ARTIST)
            val albumColumn = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.ALBUM)
            val albumIdColumn = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.ALBUM_ID)
            val durationColumn = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DURATION)
            @Suppress("DEPRECATION")
            val dataColumn = cursor.getColumnIndex(MediaStore.Audio.Media.DATA)

            while (cursor.moveToNext()) {
                val id = cursor.getLong(idColumn)
                @Suppress("DEPRECATION")
                val path = if (dataColumn >= 0) cursor.getString(dataColumn) else null
                songs.add(
                    mapOf(
                        "id" to id.toString(),
                        "uri" to ContentUris
                            .withAppendedId(MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, id)
                            .toString(),
                        "title" to cursor.getString(titleColumn),
                        "artist" to cursor.getString(artistColumn),
                        "album" to cursor.getString(albumColumn),
                        "albumId" to cursor.getLong(albumIdColumn).toString(),
                        "durationMs" to cursor.getLong(durationColumn),
                        // Direct file paths are officially readable for media
                        // on Android 11+; older releases keep the content URI.
                        "filePath" to path?.takeIf {
                            Build.VERSION.SDK_INT >= Build.VERSION_CODES.R &&
                                it.isNotBlank() && File(it).canRead()
                        },
                    ),
                )
            }
        }
        return songs
    }

    /** Lyrics embedded in the track, or null. Purely local: see LyricsReader. */
    private fun lyrics(trackId: String?, result: MethodChannel.Result) {
        if (!isGranted()) {
            result.success(null)
            return
        }
        val id = trackId?.toLongOrNull()
        if (id == null) {
            result.success(null)
            return
        }
        worker.execute {
            val text = try {
                LyricsReader.read(
                    this,
                    ContentUris.withAppendedId(
                        MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
                        id,
                    ),
                )
            } catch (error: Exception) {
                null
            }
            main.post { result.success(text) }
        }
    }

    /** Lyrics embedded in a file the user added from Downloads, or null. */
    private fun fileLyrics(path: String?, result: MethodChannel.Result) {
        if (path.isNullOrBlank()) {
            result.success(null)
            return
        }
        worker.execute {
            val text = try {
                LyricsReader.read(this, Uri.fromFile(File(path)))
            } catch (error: Exception) {
                null
            }
            main.post { result.success(text) }
        }
    }

    /**
     * Small JPEG artwork for a song, or null when there is none.
     *
     * The album thumbnail is the cheap path; when a track's album has no cover
     * (very common on phones), the picture embedded in the audio file is used
     * instead. Reading the file only needs the audio permission we already
     * have, unlike a MediaStore image query.
     */
    private fun albumArt(
        albumId: String?,
        trackId: String?,
        result: MethodChannel.Result,
    ) {
        if (!isGranted()) {
            result.success(null)
            return
        }
        worker.execute {
            val bytes = try {
                loadAlbumArt(albumId?.toLongOrNull(), trackId?.toLongOrNull())
            } catch (error: Exception) {
                null // a missing cover is normal: the UI keeps its gradient tile
            }
            main.post { result.success(bytes) }
        }
    }

    private fun loadAlbumArt(albumId: Long?, trackId: Long?): ByteArray? =
        artworkJpeg(
            albumThumbnail(albumId) ?: embeddedPicture(trackId) ?: videoFrame(trackId),
        )

    /**
     * Artwork for a file added from Downloads. Downloaders usually embed the
     * cover in the audio file; a music video has no embedded picture, so its
     * first frame is used instead.
     */
    private fun fileArtwork(path: String?, result: MethodChannel.Result) {
        if (path.isNullOrBlank()) {
            result.success(null)
            return
        }
        worker.execute {
            val bytes = try {
                artworkJpeg(
                    sidecarArtwork(path)
                        ?: embeddedPictureForFile(path)
                        ?: videoFrameForFile(path),
                )
            } catch (error: Exception) {
                null
            }
            main.post { result.success(bytes) }
        }
    }

    /**
     * The thumbnail a downloader saved next to the song (`YOU.webp`,
     * `YOU-cover.jpg`, ...). Many YouTube-style downloads ship the official
     * video image this way instead of embedding it in the audio.
     */
    private fun sidecarArtwork(path: String): Bitmap? {
        val audio = File(path)
        val folder = audio.parentFile ?: return null
        val base = audio.nameWithoutExtension
        val extensions = listOf("jpg", "jpeg", "png", "webp")
        for (extension in extensions) {
            for (name in listOf(
                "$base.$extension",
                "$base-cover.$extension",
                "${base}_cover.$extension",
                "$base cover.$extension",
            )) {
                val candidate = File(folder, name)
                if (candidate.isFile && candidate.length() > 0) {
                    decodeArtworkFile(candidate)?.let { return it }
                }
            }
        }
        // Case-insensitive fallback for downloaders that change the case.
        val image = folder.listFiles()?.firstOrNull { sibling ->
            sibling.isFile &&
                sibling.name.substringBeforeLast('.', "")
                    .equals(base, ignoreCase = true) &&
                sibling.extension.lowercase() in extensions
        }
        return image?.let { decodeArtworkFile(it) }
    }

    private fun decodeArtworkFile(file: File): Bitmap? {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(file.path, bounds)
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return null
        var sample = 1
        while (
            bounds.outWidth / (sample * 2) >= 512 &&
            bounds.outHeight / (sample * 2) >= 512
        ) {
            sample *= 2
        }
        return BitmapFactory.decodeFile(
            file.path,
            BitmapFactory.Options().apply { inSampleSize = sample },
        )
    }

    private fun embeddedPictureForFile(path: String): Bitmap? {
        val retriever = MediaMetadataRetriever()
        return try {
            retriever.setDataSource(path)
            val picture = retriever.embeddedPicture ?: return null
            BitmapFactory.decodeByteArray(picture, 0, picture.size)
        } catch (error: Exception) {
            null
        } finally {
            retriever.release()
        }
    }

    private fun videoFrameForFile(path: String): Bitmap? {
        val retriever = MediaMetadataRetriever()
        return try {
            retriever.setDataSource(path)
            var first: Bitmap? = null
            // The opening second is often a black fade; sample a few moments
            // and take the first frame with real picture in it.
            for (seconds in listOf(1L, 3L, 6L, 10L)) {
                val frame = frameAt(retriever, seconds) ?: continue
                if (first == null) first = frame
                if (!isNearlyBlack(frame)) return frame
            }
            first
        } catch (error: Exception) {
            null
        } finally {
            retriever.release()
        }
    }

    /** A 512px frame: full 4K frames are dozens of megabytes and can OOM. */
    private fun frameAt(
        retriever: MediaMetadataRetriever,
        seconds: Long,
    ): Bitmap? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            retriever.getScaledFrameAtTime(
                seconds * 1_000_000L,
                MediaMetadataRetriever.OPTION_CLOSEST_SYNC,
                512,
                512,
            )
        } else {
            retriever.getFrameAtTime(
                seconds * 1_000_000L,
                MediaMetadataRetriever.OPTION_CLOSEST_SYNC,
            )
        }

    private fun isNearlyBlack(bitmap: Bitmap): Boolean {
        val stepX = maxOf(1, bitmap.width / 12)
        val stepY = maxOf(1, bitmap.height / 12)
        var sum = 0.0
        var count = 0
        var y = 0
        while (y < bitmap.height) {
            var x = 0
            while (x < bitmap.width) {
                val pixel = bitmap.getPixel(x, y)
                sum += 0.299 * ((pixel shr 16) and 0xFF) +
                    0.587 * ((pixel shr 8) and 0xFF) +
                    0.114 * (pixel and 0xFF)
                count++
                x += stepX
            }
            y += stepY
        }
        return count > 0 && sum / count < 8.0
    }

    private fun artworkJpeg(bitmap: Bitmap?): ByteArray? {
        if (bitmap == null) return null
        val sized = scaled(bitmap, 512)
        val out = ByteArrayOutputStream()
        sized.compress(Bitmap.CompressFormat.JPEG, 88, out)
        if (sized !== bitmap) bitmap.recycle()
        sized.recycle()
        return out.toByteArray()
    }

    private fun albumThumbnail(albumId: Long?): Bitmap? {
        if (albumId == null) return null
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            try {
                contentResolver.loadThumbnail(
                    ContentUris.withAppendedId(
                        MediaStore.Audio.Albums.EXTERNAL_CONTENT_URI,
                        albumId,
                    ),
                    Size(512, 512),
                    null,
                )?.let { return it }
            } catch (error: Exception) {
                // fall through to the legacy endpoint
            }
        }
        return legacyAlbumArt(albumId)
    }

    private fun legacyAlbumArt(albumId: Long): Bitmap? {
        val uri = ContentUris.withAppendedId(
            Uri.parse("content://media/external/audio/albumart"),
            albumId,
        )
        val bytes = contentResolver.openInputStream(uri)?.use { it.readBytes() } ?: return null
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)
        var sample = 1
        while (bounds.outWidth / (sample * 2) >= 512) sample *= 2
        val options = BitmapFactory.Options().apply { inSampleSize = sample }
        return BitmapFactory.decodeByteArray(bytes, 0, bytes.size, options)
    }

    private fun embeddedPicture(trackId: Long?): Bitmap? {
        if (trackId == null) return null
        val retriever = MediaMetadataRetriever()
        return try {
            retriever.setDataSource(
                this,
                ContentUris.withAppendedId(MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, trackId),
            )
            val picture = retriever.embeddedPicture ?: return null
            BitmapFactory.decodeByteArray(picture, 0, picture.size)
        } catch (error: Exception) {
            null
        } finally {
            retriever.release()
        }
    }

    /** First frame of a downloaded music video, used when it has no cover. */
    private fun videoFrame(trackId: Long?): Bitmap? {
        if (trackId == null) return null
        val retriever = MediaMetadataRetriever()
        return try {
            retriever.setDataSource(
                this,
                ContentUris.withAppendedId(MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, trackId),
            )
            frameAt(retriever, 1L)
        } catch (error: Exception) {
            null
        } finally {
            retriever.release()
        }
    }

    private fun scaled(bitmap: Bitmap, max: Int): Bitmap {
        val largest = maxOf(bitmap.width, bitmap.height)
        if (largest <= max) return bitmap
        val ratio = max.toFloat() / largest
        return Bitmap.createScaledBitmap(
            bitmap,
            (bitmap.width * ratio).roundToInt(),
            (bitmap.height * ratio).roundToInt(),
            true,
        )
    }
}
