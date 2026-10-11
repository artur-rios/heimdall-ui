import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'platform_file_saver.dart';

/// Hands a file the application produced to the person using it.
///
/// Behind an interface so a screen never touches the platform's file system or
/// the browser directly — and so no test does either.
abstract interface class FileSaver {
  /// Saves [contents] as a file named [fileName].
  ///
  /// Returns where the file was written, or `null` when it was handed to the
  /// browser, which decides that for itself. Throws when it could not be saved
  /// at all.
  Future<String?> saveText({
    required String fileName,
    required String contents,
    String mimeType = 'application/json',
  });
}

/// The platform's [FileSaver]: a browser download on the web, and the
/// downloads folder on every other target. Overridden in tests with a fake.
final Provider<FileSaver> fileSaverProvider = Provider<FileSaver>(
  (ref) => platformFileSaver(),
);
