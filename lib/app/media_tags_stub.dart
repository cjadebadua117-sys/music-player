import '../models/track.dart';

/// The web build has no background audio service, so sources carry no tag.
Object? mediaTagFor(Track track) => null;
