package com.freebuff.music_player

import android.content.Context
import android.net.Uri

/**
 * Reads lyrics that are stored inside the audio file itself.
 *
 * There is no network path here on purpose: the app has no INTERNET permission,
 * so lyrics can only come from tags the file already carries (ID3 USLT, MP4
 * ©lyr, or a Vorbis-style LYRICS field). LRC timestamps, when present, are
 * parsed on the Dart side.
 */
object LyricsReader {

    /** Do not load a whole music video into memory just to look for lyrics. */
    private const val MAX_BYTES = 24L * 1024 * 1024

    fun read(context: Context, uri: Uri): String? {
        val size = try {
            context.contentResolver.openFileDescriptor(uri, "r")?.use {
                it.statSize
            }
        } catch (error: Exception) {
            null
        }
        if (size != null && size > MAX_BYTES) return null

        val data = context.contentResolver.openInputStream(uri)?.use {
            it.readBytes()
        } ?: return null
        return fromId3(data) ?: fromMp4(data) ?: fromTextTag(data)
    }

    private fun fromId3(data: ByteArray): String? {
        if (data.size < 10) return null
        if (data[0] != 0x49.toByte() || data[1] != 0x44.toByte() || data[2] != 0x33.toByte()) {
            return null
        }
        val version = data[3].toInt() and 0xff
        val flags = data[5].toInt() and 0xff
        val tagSize = syncSafe(data, 6)
        var pos = 10
        if (flags and 0x40 != 0 && pos + 4 <= data.size) {
            // Extended header: its size includes itself on v2.3, not on v2.4.
            val ext = if (version == 4) syncSafe(data, pos) else beInt(data, pos) + 4
            pos += ext
        }
        val end = minOf(data.size, 10 + tagSize)
        val headerSize = if (version == 2) 6 else 10

        while (pos + headerSize <= end) {
            val id = String(
                data,
                pos,
                if (version == 2) 3 else 4,
                Charsets.ISO_8859_1,
            )
            if (id.isEmpty() || id[0] == '\u0000') break
            val frameSize = when {
                version == 2 -> be24(data, pos + 3)
                version == 4 -> syncSafe(data, pos + 4)
                else -> beInt(data, pos + 4)
            }
            val frameStart = pos + headerSize
            if (frameSize <= 0 || frameStart + frameSize > data.size) break
            if (id == "USLT" || id == "ULT") {
                return decodeLyricFrame(data, frameStart, frameStart + frameSize)
            }
            pos = frameStart + frameSize
        }
        return null
    }

    private fun decodeLyricFrame(data: ByteArray, start: Int, end: Int): String? {
        if (start + 4 >= end) return null
        val encoding = data[start].toInt() and 0xff
        var pos = start + 4 // encoding byte + 3-byte language
        val wide = encoding == 1 || encoding == 2

        // Skip the human-readable description, then the lyrics follow.
        while (pos < end) {
            if (wide) {
                if (pos + 1 < end && data[pos] == 0.toByte() && data[pos + 1] == 0.toByte()) {
                    pos += 2
                    break
                }
                pos += 2
            } else {
                if (data[pos] == 0.toByte()) {
                    pos += 1
                    break
                }
                pos += 1
            }
        }
        if (pos >= end) return null

        val charset = when (encoding) {
            1 -> Charsets.UTF_16 // BOM in the payload
            2 -> Charsets.UTF_16BE
            3 -> Charsets.UTF_8
            else -> Charsets.ISO_8859_1
        }
        return String(data, pos, end - pos, charset).trim('\u0000', '\r', '\n', ' ')
    }

    private fun fromMp4(data: ByteArray): String? {
        val key = byteArrayOf(0xA9.toByte(), 'l'.code.toByte(), 'y'.code.toByte(), 'r'.code.toByte())
        var idx = indexOf(data, key)
        while (idx >= 0) {
            // The text lives in a nested `data` atom: size, 'data', type, locale, text.
            val dataAtom = indexOf(data, "data".toByteArray(), idx, minOf(data.size, idx + 256))
            if (dataAtom >= 0) {
                val start = dataAtom + 12
                if (start < data.size) {
                    var stop = start
                    while (stop < data.size && data[stop] != 0.toByte()) stop++
                    val text = String(data, start, stop - start, Charsets.UTF_8).trim()
                    if (text.isNotEmpty()) return text
                }
            }
            idx = indexOf(data, key, idx + key.size)
        }
        return null
    }

    private fun fromTextTag(data: ByteArray): String? {
        val keys = listOf("UNSYNCEDLYRICS=", "LYRICS=", "UNSYNCED LYRICS=")
        for (key in keys) {
            val needle = key.toByteArray()
            var idx = indexOf(data, needle)
            while (idx >= 0) {
                var stop = idx + needle.size
                while (stop < data.size && data[stop] != 0.toByte()) stop++
                if (stop - (idx + needle.size) in 10..200_000) {
                    val text = String(
                        data,
                        idx + needle.size,
                        stop - (idx + needle.size),
                        Charsets.UTF_8,
                    )
                    val cleaned = text
                        .replace(Regex("[\\u0000-\\u0008\\u000B\\u000C\\u000E-\\u001F]"), "")
                        .trim()
                    if (cleaned.length > 10 && cleaned.any { it.isLetter() }) return cleaned
                }
                idx = indexOf(data, needle, idx + 1)
            }
        }
        return null
    }

    private fun syncSafe(b: ByteArray, offset: Int): Int {
        if (offset + 4 > b.size) return 0
        return ((b[offset].toInt() and 0x7f) shl 21) or
            ((b[offset + 1].toInt() and 0x7f) shl 14) or
            ((b[offset + 2].toInt() and 0x7f) shl 7) or
            (b[offset + 3].toInt() and 0x7f)
    }

    private fun beInt(b: ByteArray, offset: Int): Int {
        if (offset + 4 > b.size) return 0
        return ((b[offset].toInt() and 0xff) shl 24) or
            ((b[offset + 1].toInt() and 0xff) shl 16) or
            ((b[offset + 2].toInt() and 0xff) shl 8) or
            (b[offset + 3].toInt() and 0xff)
    }

    private fun be24(b: ByteArray, offset: Int): Int {
        if (offset + 3 > b.size) return 0
        return ((b[offset].toInt() and 0xff) shl 16) or
            ((b[offset + 1].toInt() and 0xff) shl 8) or
            (b[offset + 2].toInt() and 0xff)
    }

    private fun indexOf(
        haystack: ByteArray,
        needle: ByteArray,
        from: Int = 0,
        to: Int = haystack.size,
    ): Int {
        if (needle.isEmpty()) return -1
        val last = minOf(to, haystack.size) - needle.size
        var i = maxOf(0, from)
        while (i <= last) {
            var hit = true
            for (j in needle.indices) {
                if (haystack[i + j] != needle[j]) {
                    hit = false
                    break
                }
            }
            if (hit) return i
            i++
        }
        return -1
    }
}
