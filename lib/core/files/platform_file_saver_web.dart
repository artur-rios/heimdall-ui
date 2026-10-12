import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'file_saver.dart';

/// Offers the file to the browser as a download.
FileSaver platformFileSaver() => const _BrowserDownloadSaver();

class _BrowserDownloadSaver implements FileSaver {
  const _BrowserDownloadSaver();

  @override
  Future<String?> saveText({
    required String fileName,
    required String contents,
    String mimeType = 'application/json',
  }) async {
    final blob = web.Blob(
      <JSAny>[contents.toJS].toJS,
      web.BlobPropertyBag(type: mimeType),
    );
    final url = web.URL.createObjectURL(blob);
    final anchor = web.HTMLAnchorElement()
      ..href = url
      ..download = fileName
      ..style.display = 'none';

    web.document.body?.append(anchor);
    anchor.click();
    anchor.remove();

    // The object URL holds the whole document in memory until it is revoked.
    // Not at once: some browsers only start the download after the click has
    // returned.
    Timer(const Duration(minutes: 1), () => web.URL.revokeObjectURL(url));

    return null;
  }
}
