import 'dart:io';

import 'src/test_bundles.dart';

/// Writes the test suite into a few bundle files, each of which imports a
/// share of the test files and runs every one of them in a group named after
/// its path.
///
/// Run from the repository root:
///
/// ```
/// dart run tool/test_bundles.dart [<directory>] [<bundles>]
/// ```
///
/// The defaults are `build/test-bundles` and 4. `ci/analyze-and-test.sh` runs
/// the suite through these files instead of one test file at a time:
/// `flutter test` compiles its entry points one after the other whatever its
/// concurrency, so with one entry point per test file most of a run was spent
/// compiling and loading 140-odd files in a row. A bundle is compiled once and
/// runs its share in one process, and the bundles run side by side.
///
/// What a bundle gives up is a process per test file: the files of a bundle
/// share an isolate, so no test may depend on running alone. A test that sets
/// global state (`SharedPreferences.setMockInitialValues`,
/// `PageTitle.reset`, a mock method channel handler) sets it in its own
/// `setUp` and puts it back in a tear-down. flutter_test's widget binding,
/// once the first `testWidgets` has created it, also answers every
/// `HttpClient` request in the isolate with HTTP 400; that is harmless here
/// because no test reaches the network (CONTRIBUTING.md), but a test that
/// starts a loopback server would have to be kept out of the bundles.
///
/// `flutter test` with a path still runs each file in its own process, which
/// is the loop for one area. The directory is emptied and rewritten on every
/// run; it lives under `build/`, which is neither committed nor analysed.
void main(List<String> arguments) {
  final directory = arguments.isNotEmpty ? arguments[0] : 'build/test-bundles';
  final count = arguments.length > 1 ? int.tryParse(arguments[1]) : 4;

  if (count == null || count < 1) {
    stderr.writeln(
      'tool/test_bundles.dart: the bundle count must be 1 or more',
    );
    exitCode = 2;

    return;
  }

  // A bundle directory under test/ must not bundle the bundles of a run before.
  final written = '${posixPath(directory)}/';
  final tests =
      Directory('test')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('_test.dart'))
          .where((file) => !posixPath(file.path).startsWith(written))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  if (tests.isEmpty) {
    stderr.writeln('tool/test_bundles.dart: no test files under test/');
    exitCode = 1;

    return;
  }

  final bundles = planTestBundles(<String, int>{
    for (final file in tests)
      posixPath(file.path): testWeight(file.readAsStringSync()),
  }, count);

  final output = Directory(directory);
  if (output.existsSync()) output.deleteSync(recursive: true);
  output.createSync(recursive: true);

  for (final (index, files) in bundles.indexed) {
    final bundle = File('${posixPath(directory)}/bundle_${index}_test.dart')
      ..writeAsStringSync(testBundleSource(files, directory: directory));
    stdout.writeln(posixPath(bundle.path));
  }
}
