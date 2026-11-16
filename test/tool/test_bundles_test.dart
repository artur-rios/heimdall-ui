import 'package:flutter_test/flutter_test.dart';

import '../../tool/src/test_bundles.dart';

void main() {
  test('GivenATestWidgetsCall_WhenChecked_ThenItUsesTheWidgetBinding', () {
    // Given
    const source = "testWidgets('a', (tester) async {});";

    // When
    final uses = usesWidgetBinding(source);

    // Then
    expect(uses, isTrue);
  });

  test('GivenAWidgetTester_WhenChecked_ThenItUsesTheWidgetBinding', () {
    // Given
    const source = 'Future<void> pump(WidgetTester tester) async {}';

    // When
    final uses = usesWidgetBinding(source);

    // Then
    expect(uses, isTrue);
  });

  test('GivenAnEnsuredBinding_WhenChecked_ThenItUsesTheWidgetBinding', () {
    // Given
    const source = 'TestWidgetsFlutterBinding.ensureInitialized();';

    // When
    final uses = usesWidgetBinding(source);

    // Then
    expect(uses, isTrue);
  });

  test('GivenOnlyPlainTests_WhenChecked_ThenItDoesNotUseTheBinding', () {
    // Given
    const source = "test('a', () {}); // a widget test elsewhere";

    // When
    final uses = usesWidgetBinding(source);

    // Then
    expect(uses, isFalse);
  });

  test('GivenTwoFilesOfOneSize_WhenWeighed_ThenTheWidgetOneWeighsMore', () {
    // Given
    const widget = "testWidgets('a', (t) {});";
    final plain = "test('a', () {});".padRight(widget.length);

    // When
    final widgetWeight = testWeight(widget);
    final plainWeight = testWeight(plain);

    // Then
    expect(plainWeight, widget.length);
    expect(widgetWeight, widget.length * widgetWeightFactor);
  });

  test('GivenNoBundles_WhenPlanned_ThenItThrows', () {
    // Given
    const weights = <String, int>{'test/a_test.dart': 1};

    // When
    List<List<String>> plan() => planTestBundles(weights, 0);

    // Then
    expect(plan, throwsArgumentError);
  });

  test('GivenNoFiles_WhenPlanned_ThenThereAreNoBundles', () {
    // Given
    const weights = <String, int>{};

    // When
    final bundles = planTestBundles(weights, 4);

    // Then
    expect(bundles, isEmpty);
  });

  test('GivenFewerFilesThanBundles_WhenPlanned_ThenEmptyOnesAreDropped', () {
    // Given
    const weights = <String, int>{'test/a_test.dart': 1, 'test/b_test.dart': 2};

    // When
    final bundles = planTestBundles(weights, 4);

    // Then
    expect(bundles, <List<String>>[
      <String>['test/b_test.dart'],
      <String>['test/a_test.dart'],
    ]);
  });

  test('GivenFilesOfMixedWeight_WhenPlanned_ThenTheBundlesBalance', () {
    // Given
    const weights = <String, int>{
      'test/a_test.dart': 9,
      'test/b_test.dart': 5,
      'test/c_test.dart': 4,
      'test/d_test.dart': 3,
      'test/e_test.dart': 3,
    };

    // When
    final bundles = planTestBundles(weights, 2);

    // Then — 9 + 3 against 5 + 4 + 3.
    expect(bundles, <List<String>>[
      <String>['test/a_test.dart', 'test/d_test.dart'],
      <String>['test/b_test.dart', 'test/c_test.dart', 'test/e_test.dart'],
    ]);
  });

  test('GivenFilesOfEqualWeight_WhenPlanned_ThenTheyAreTakenInPathOrder', () {
    // Given
    const weights = <String, int>{
      'test/c_test.dart': 1,
      'test/a_test.dart': 1,
      'test/b_test.dart': 1,
    };

    // When
    final bundles = planTestBundles(weights, 2);

    // Then
    expect(bundles, <List<String>>[
      <String>['test/a_test.dart', 'test/c_test.dart'],
      <String>['test/b_test.dart'],
    ]);
  });

  test('GivenOneBundle_WhenPlanned_ThenEveryFileIsInItSorted', () {
    // Given
    const weights = <String, int>{'test/b_test.dart': 7, 'test/a_test.dart': 1};

    // When
    final bundles = planTestBundles(weights, 1);

    // Then
    expect(bundles, <List<String>>[
      <String>['test/a_test.dart', 'test/b_test.dart'],
    ]);
  });

  test('GivenFiles_WhenABundleIsWritten_ThenEachRunsInAGroupNamedAfterIt', () {
    // Given
    const files = <String>['test/app/a_test.dart', 'test/core/b_test.dart'];

    // When
    final source = testBundleSource(files, directory: 'build/test-bundles');

    // Then
    expect(
      source,
      '// Written by tool/test_bundles.dart. Do not edit.\n'
      "import 'package:flutter_test/flutter_test.dart';\n"
      '\n'
      "import '../../test/app/a_test.dart' as t0;\n"
      "import '../../test/core/b_test.dart' as t1;\n"
      '\n'
      'void main() {\n'
      "  group('app/a_test.dart', t0.main);\n"
      "  group('core/b_test.dart', t1.main);\n"
      '}\n',
    );
  });

  test('GivenAWindowsDirectory_WhenABundleIsWritten_ThenImportsArePosix', () {
    // Given
    const files = <String>['test/a_test.dart'];

    // When
    final source = testBundleSource(files, directory: r'.\build\bundles\');

    // Then
    expect(source, contains("import '../../test/a_test.dart' as t0;"));
  });

  test('GivenALongPath_WhenABundleIsWritten_ThenTheImportIsWrappedAsFormatted', () {
    // Given
    const file =
        'test/features/applications/presentation/a_much_longer_file_name_test.dart';

    // When
    final source = testBundleSource(<String>[
      file,
    ], directory: 'build/test-bundles');

    // Then
    expect(source, contains("import '../../$file'\n    as t0;\n"));
    expect(
      source,
      contains(
        "  group(\n"
        "    'features/applications/presentation/a_much_longer_file_name_test.dart',\n"
        '    t0.main,\n'
        '  );\n',
      ),
    );
  });

  test('GivenADirectoryOutsideTheRepository_WhenWritten_ThenItThrows', () {
    // Given
    const files = <String>['test/a_test.dart'];

    // When
    String write() => testBundleSource(files, directory: '../bundles');

    // Then
    expect(write, throwsArgumentError);
  });

  test('GivenABackslashedPath_WhenMadePosix_ThenItHasForwardSlashes', () {
    // Given
    const path = r'test\core\a_test.dart';

    // When
    final posix = posixPath(path);

    // Then
    expect(posix, 'test/core/a_test.dart');
  });
}
