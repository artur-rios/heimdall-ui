import 'dart:io';

import 'src/read_source.dart';

/// Refreshes the vendored OpenAPI specification at `api/heimdall.json`.
///
/// Run from the repository root, with either a path or a URL:
///
/// ```
/// dart run tool/refresh_openapi.dart ../heimdall-api/docs/openapi/heimdall.json
/// dart run tool/refresh_openapi.dart https://heimdall.example.com/swagger/v1/swagger.json
/// ```
///
/// Regenerate the client afterwards with `dart run tool/generate_api_client.dart`
/// and commit both together — CI fails when they disagree.
Future<void> main(List<String> args) async {
  if (args.length != 1) {
    stderr.writeln('usage: dart run tool/refresh_openapi.dart <path-or-url>');
    exitCode = 64;

    return;
  }

  final source = args.single;
  final target = File('api/heimdall.json');
  final previous = target.existsSync() ? target.readAsStringSync() : '';

  final fetched = await readSource(source);

  if (fetched == null) {
    return;
  }

  target.parent.createSync(recursive: true);
  target.writeAsStringSync(fetched);
  stdout.writeln(
    previous == fetched ? 'specification unchanged' : 'specification updated',
  );
}
