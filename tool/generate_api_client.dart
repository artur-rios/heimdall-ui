import 'dart:io';

/// Regenerates `packages/heimdall_api_client` from `api/heimdall.json`.
///
/// Run from the repository root:
///
/// ```
/// dart run tool/generate_api_client.dart
/// ```
///
/// The pipeline is: `swagger_parser` emits the clients and models,
/// `build_runner` emits the `.g.dart` bodies, and `dart format` settles the
/// line breaking. Every step is deterministic, so a clean run reproduces the
/// committed tree byte for byte — which is what makes the drift check in CI
/// mean something.
Future<void> main() async {
  await _run('dart', <String>['run', 'swagger_parser']);

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

  // The generators emit their own line breaking, which `dart format` at the
  // repository root would then rewrite — leaving the committed tree different
  // from a fresh generation and failing the drift check for no real reason.
  // Formatting here makes the two agree.
  await _run('dart', <String>['format', 'packages/heimdall_api_client']);
}

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
