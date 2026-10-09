import 'dart:convert';
import 'dart:io';

/// Reads [source] — a local path, or an `http://` or `https://` URL — as text.
///
/// Returns `null` after writing the reason to stderr and setting [exitCode],
/// so a refresh script can simply stop.
Future<String?> readSource(String source) async {
  if (source.startsWith('http://') || source.startsWith('https://')) {
    final client = HttpClient();

    try {
      final request = await client.getUrl(Uri.parse(source));
      final response = await request.close();

      if (response.statusCode != 200) {
        stderr.writeln('fetch failed: HTTP ${response.statusCode}');
        exitCode = 1;

        return null;
      }

      return await response.transform(utf8.decoder).join();
    } finally {
      client.close();
    }
  }

  final file = File(source);

  if (!file.existsSync()) {
    stderr.writeln('no such file: $source');
    exitCode = 66;

    return null;
  }

  return file.readAsStringSync();
}
