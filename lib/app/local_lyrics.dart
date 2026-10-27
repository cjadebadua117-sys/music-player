import '../models/lyrics.dart';

/// Manually verified lyrics for a song that the public databases did not
/// cover. Bundled so the demo and offline-first guarantee stay intact while
/// the app's online fallback catches up. Replace this file with a real
/// source once the catalogue supports the song.
class LocalLyrics {
  /// Timed, not plain text: the player highlights the line that is playing
  /// instead of showing raw "[00:30.53]" markers.
  static Lyrics panaginipNicole() =>
      Lyrics.parse(_lrc) ?? Lyrics.literal(_lrc);

  static const _lrc = '''
[00:30.53] Bawat pikit ng aking mata, tanging ikaw nakikita
[00:44.56] Utak ko ay punong-puno ng imahinasyon, kasama ka
[00:57.96] Isang himala na lang kung mapapasa'kin ka
[01:10.99] Parang panaginip 'pag ika'y aking kapiling
[01:24.72] Huwag kang tumingin sa 'kin, ako'y nahuhumaling
[01:38.48] Ako'y nahuhumaling sa 'yo, sa 'yo, sa 'yo
[01:53.28] Natutulala na lang sa 'yo, napapabagal mo 'king mundo
[02:06.46] Nasisilayan ko na ang kinabukasan ko sa 'yo
[02:20.33] Imahinasyon pa rin ba 'to? Ika'y narito sa tabi ko
[02:36.53] Parang panaginip 'pag ika'y aking kapiling
[02:50.44] Huwag kang tumingin sa 'kin, ako'y nahuhumaling
[03:04.17] Ako'y nahuhumaling sa 'yo
[03:24.12]
[03:40.05] Paulit-ulit kang tumatakbo sa isip
[03:53.69] Paulit-ulit na lang pinapanalangin ka
[04:07.18] Maaari bang hawakan ang iyong mga kamay?
[04:21.54] Tayo na (tayo na), lilipad na nang sabay
[04:37.26] Parang panaginip 'pag ika'y aking kapiling
[04:50.30] Huwag kang tumingin sa 'kin, ako'y nahuhumaling sa 'yo
[05:08.27]

[05:20.00] (balik sa realidad)
''';
}
