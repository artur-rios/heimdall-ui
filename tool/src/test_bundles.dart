/// How `tool/test_bundles.dart` shares the test files out into bundles and
/// what a bundle's source is. Kept apart from the script so that
/// `test/tool/test_bundles_test.dart` can test it without touching the disk.
library;

/// How many times more a file that uses the widget binding weighs than a
/// plain one of the same size.
///
/// Measured on the suite as it was when the bundles came in (2,215 tests):
/// the widget files ran for about 250 ms per kilobyte of source and the plain
/// ones, controller and repository tests against fakes, for about 10. Sharing
/// the files out by size alone would give the bundle that drew the plain files
/// almost nothing to run.
const int widgetWeightFactor = 25;

/// Whether a test file's [source] uses flutter_test's widget binding.
bool usesWidgetBinding(String source) => _widgetBinding.hasMatch(source);

final RegExp _widgetBinding = RegExp(
  r'\btestWidgets\s*\(|\bWidgetTester\b|WidgetsFlutterBinding\b',
);

/// What a test file is expected to cost to run, from its [source].
int testWeight(String source) =>
    source.length * (usesWidgetBinding(source) ? widgetWeightFactor : 1);

/// Shares the test files in [weights] (posix path to weight) out onto at most
/// [count] bundles of about equal weight.
///
/// The heaviest file goes first onto the lightest bundle; ties go to the lower
/// bundle, and files of equal weight are taken in path order. Empty bundles
/// are dropped and each bundle's files are sorted by path, so the plan only
/// changes when the suite does.
List<List<String>> planTestBundles(Map<String, int> weights, int count) {
  if (count < 1) {
    throw ArgumentError.value(count, 'count', 'must be 1 or more');
  }

  final ordered = weights.keys.toList()
    ..sort((a, b) {
      final byWeight = weights[b]!.compareTo(weights[a]!);

      return byWeight != 0 ? byWeight : a.compareTo(b);
    });
  final bundles = <List<String>>[for (var i = 0; i < count; i++) <String>[]];
  final totals = List<int>.filled(count, 0);

  for (final file in ordered) {
    var lightest = 0;

    for (var i = 1; i < count; i++) {
      if (totals[i] < totals[lightest]) lightest = i;
    }

    bundles[lightest].add(file);
    totals[lightest] += weights[file]!;
  }

  return <List<String>>[
    for (final bundle in bundles)
      if (bundle.isNotEmpty) bundle..sort(),
  ];
}

/// The source of a bundle written to the posix directory [directory],
/// relative to the repository's root, that runs each of [files] (posix paths
/// under `test/`) in a group named after its path under `test/`, so that a
/// failure still names the file it is in.
String testBundleSource(List<String> files, {required String directory}) {
  final segments = posixPath(directory)
      .split('/')
      .where((segment) => segment.isNotEmpty && segment != '.');

  if (segments.contains('..')) {
    throw ArgumentError.value(
      directory,
      'directory',
      'must be inside the repository',
    );
  }

  final up = '../' * segments.length;
  final source = StringBuffer()
    ..writeln('// Written by tool/test_bundles.dart. Do not edit.')
    ..writeln("import 'package:flutter_test/flutter_test.dart';")
    ..writeln();

  // Broken where `dart format` would break it, so that `dart format
  // --set-exit-if-changed .` still passes with the bundles on disk.
  for (final (index, file) in files.indexed) {
    final import = "import '$up$file' as t$index;";
    source.writeln(
      import.length <= 80 ? import : "import '$up$file'\n    as t$index;",
    );
  }

  source
    ..writeln()
    ..writeln('void main() {');

  for (final (index, file) in files.indexed) {
    final name = file.startsWith('test/') ? file.substring(5) : file;
    final group = "  group('$name', t$index.main);";
    source.writeln(
      group.length <= 80
          ? group
          : "  group(\n    '$name',\n    t$index.main,\n  );",
    );
  }

  source.writeln('}');

  return source.toString();
}

/// [path] with forward slashes, as an import and a test name spell it.
String posixPath(String path) => path.replaceAll(r'\', '/');
