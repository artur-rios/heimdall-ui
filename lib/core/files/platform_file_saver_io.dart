import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'file_saver.dart';

/// Writes into the downloads folder, where a person looks for a file they
/// asked for.
FileSaver platformFileSaver() => const _DownloadsFolderSaver();

class _DownloadsFolderSaver implements FileSaver {
  const _DownloadsFolderSaver();

  @override
  Future<String?> saveText({
    required String fileName,
    required String contents,
    String mimeType = 'application/json',
  }) async {
    final directory = await _downloads();
    final file = File('${directory.path}${Platform.pathSeparator}$fileName');

    await file.writeAsString(contents, flush: true);

    return file.path;
  }

  /// The downloads folder — on Android, the application's own one in shared
  /// storage. A target that has none falls back to the documents folder, so
  /// the file is still saved somewhere the screen can name.
  static Future<Directory> _downloads() async {
    try {
      final downloads = await getDownloadsDirectory();

      if (downloads != null) {
        return await downloads.create(recursive: true);
      }
    } on Object {
      // No downloads folder on this target; the documents folder will do.
    }

    return getApplicationDocumentsDirectory();
  }
}
