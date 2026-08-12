import 'dart:io';

/// Regenerates `packages/heimdall_api_client` from `api/heimdall.json`.
///
/// Run from the repository root:
///
/// ```
/// dart run tool/generate_api_client.dart
/// ```
///
/// The pipeline is: `swagger_parser` emits the clients and models, this script
/// repairs the colliding parameter names described below, and `build_runner`
/// emits the `.g.dart` bodies. Every step is deterministic, so the drift check
/// in CI stays meaningful.
Future<void> main() async {
  await _run('dart', <String>['run', 'swagger_parser']);

  final renamed = _resolveParameterCollisions(
    Directory('packages/heimdall_api_client/lib/clients'),
  );
  stdout.writeln('renamed $renamed colliding query parameter(s)');

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

/// The Heimdall specification declares, on the same operation, a path parameter
/// `scopeId` and a query parameter `ScopeId` — the filter object's own property,
/// which the path already supplies. Dart identifiers are case-sensitive but the
/// generator lower-camel-cases both names, so the emitted method has two
/// parameters called `scopeId` and does not compile.
///
/// This renames the **query** side to `<name>Filter`, leaving its wire name in
/// the `@Query('…')` annotation untouched, so the request is unchanged and only
/// the Dart identifier differs.
int _resolveParameterCollisions(Directory clients) {
  if (!clients.existsSync()) {
    throw StateError('generated clients not found at ${clients.path}');
  }

  final pathParameter = RegExp(r"@Path\('[^']*'\)\s+required\s+\S+\s+(\w+),");
  final queryParameter = RegExp(r"(@Query\('[^']*'\)\s+\S+\s+)(\w+),");
  var renamed = 0;

  for (final file in clients.listSync().whereType<File>()) {
    if (!file.path.endsWith('.dart')) {
      continue;
    }

    final lines = file.readAsLinesSync();
    final rewritten = <String>[];
    final pathNames = <String>{};

    for (final line in lines) {
      // A method signature ends at its closing paren, which is where the
      // parameter block — and the names in scope — ends.
      if (line.trimLeft().startsWith('})')) {
        pathNames.clear();
      }

      final path = pathParameter.firstMatch(line);

      if (path != null) {
        pathNames.add(path.group(1)!);
        rewritten.add(line);

        continue;
      }

      final query = queryParameter.firstMatch(line);

      if (query != null && pathNames.contains(query.group(2))) {
        rewritten.add(
          line.replaceFirst(
            queryParameter,
            '${query.group(1)}${query.group(2)}Filter,',
          ),
        );
        renamed++;

        continue;
      }

      rewritten.add(line);
    }

    if (renamed > 0) {
      file.writeAsStringSync('${rewritten.join('\n')}\n');
    }
  }

  return renamed;
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
