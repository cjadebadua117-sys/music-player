import 'dart:typed_data';

import '../models/track.dart';

/// Platforms without `dart:io` cannot cache covers, so they keep the gradient.
Future<Uint8List?> lookupCoverArt(Track track) async => null;
