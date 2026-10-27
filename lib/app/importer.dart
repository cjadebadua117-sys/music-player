/// Picking songs off the device (and the disk checks that go with it) only
/// works where there is a real filesystem, so the web build gets a stub.
library;

export 'importer_stub.dart' if (dart.library.io) 'importer_io.dart';
