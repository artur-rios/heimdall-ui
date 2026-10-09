import 'dart:io';

import 'src/read_source.dart';

/// Refreshes the bundled privacy notice at `assets/privacy/privacy_notice.md`.
///
/// The Heimdall API owns the notice; this copies its
/// `docs/requirements/Privacy Notice.md` verbatim. Run from the repository
/// root, with either a path or a URL:
///
/// ```
/// dart run tool/refresh_privacy_notice.dart "../heimdall-api/docs/requirements/Privacy Notice.md"
/// dart run tool/refresh_privacy_notice.dart "https://raw.githubusercontent.com/artur-rios/heimdall-api/main/docs/requirements/Privacy%20Notice.md"
/// ```
///
/// Copy from the API's `main`: that is the notice in force, and the version
/// the `/privacy` page shows is the one people are held to have been told.
Future<void> main(List<String> args) async {
  if (args.length != 1) {
    stderr.writeln(
      'usage: dart run tool/refresh_privacy_notice.dart <path-or-url>',
    );
    exitCode = 64;

    return;
  }

  final target = File('assets/privacy/privacy_notice.md');
  final previous = target.existsSync() ? target.readAsStringSync() : '';

  final fetched = await readSource(args.single);

  if (fetched == null) {
    return;
  }

  target.parent.createSync(recursive: true);
  target.writeAsStringSync(fetched);
  stdout.writeln(previous == fetched ? 'notice unchanged' : 'notice updated');
}
