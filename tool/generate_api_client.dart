import 'dart:io';

import 'src/encode_path_parameters.dart';

/// Regenerates `packages/heimdall_api_client` from `api/heimdall.json`.
///
/// Run from the repository root:
///
/// ```
/// dart run tool/generate_api_client.dart
/// ```
///
/// The pipeline is: the previous output is removed, `swagger_parser` emits
/// the clients and models (one folder per API tag), `build_runner` emits the
/// `.g.dart` bodies, every path parameter in each client library is wrapped so
/// it is sent percent-encoded as one segment, and `dart format` settles the
/// line breaking. Every step is deterministic, so a clean run reproduces the
/// committed tree byte for byte — which is what makes the drift check in CI
/// mean something.
Future<void> main() async {
  // From an empty directory, so a client or model the specification no longer
  // has disappears instead of lingering beside the new output.
  final output = Directory(_output);
  if (output.existsSync()) {
    output.deleteSync(recursive: true);
  }

  await _run('dart', <String>['run', 'swagger_parser']);

  // swagger_parser's guard against two runs writing at once; it holds nothing.
  final lock = File('$_output/.swagger_parser.lock');
  if (lock.existsSync()) {
    lock.deleteSync();
  }

  await _run('dart', <String>[
    'pub',
    'get',
  ], workingDirectory: 'packages/heimdall_api_client');

  await _run('dart', <String>[
    'run',
    'build_runner',
    'build',
    '--delete-conflicting-outputs',
  ], workingDirectory: 'packages/heimdall_api_client');

  // retrofit and the direct Dio fallbacks beside it interpolate path
  // parameters as they are; an id holding `/` or `?` would otherwise reach a
  // different endpoint.
  final declarations = output
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('_client.dart'));
  for (final declaration in declarations) {
    final part = File(
      declaration.path.replaceFirst(RegExp(r'\.dart$'), '.g.dart'),
    );
    final encoded = encodeClientLibrary(
      declaration: declaration.readAsStringSync(),
      part: part.readAsStringSync(),
    );
    declaration.writeAsStringSync(encoded.declaration);
    part.writeAsStringSync(encoded.part);
  }

  // The generators emit their own line breaking, which `dart format` at the
  // repository root would then rewrite — leaving the committed tree different
  // from a fresh generation and failing the drift check for no real reason.
  // Formatting here makes the two agree.
  await _run('dart', <String>['format', 'packages/heimdall_api_client']);
}

const String _output = 'packages/heimdall_api_client/lib';

Future<void> _run(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
}) async {
  final result = await Process.run(
    executable,
    arguments,
    workingDirectory: workingDirectory,
    runInShell: true,
  );

  stdout.write(result.stdout);
  stderr.write(result.stderr);

  if (result.exitCode != 0) {
    throw ProcessException(
      executable,
      arguments,
      'command failed',
      result.exitCode,
    );
  }
}
