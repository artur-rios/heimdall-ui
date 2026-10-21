import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/shared/widgets/page_title.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<String> titles;

  setUp(() {
    PageTitle.reset();
    titles = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'SystemChrome.setApplicationSwitcherDescription') {
            titles.add((call.arguments as Map)['label'] as String);
          }

          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Widget screen(String name, {Widget? next}) => Scaffold(
    body: PageTitle(title: name, child: next ?? const SizedBox()),
  );

  testWidgets('GivenAScreen_WhenShown_ThenTheTitleNamesItAndTheApp', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: screen('Permissions')));

    expect(titles.last, 'Permissions - Heimdall');
  });

  testWidgets(
    'GivenAScreenOverAnother_WhenTheOneUnderRebuilds_ThenTheTopTitleStays',
    (tester) async {
      final underneath = ValueNotifier<int>(0);
      await tester.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder<int>(
            valueListenable: underneath,
            builder: (context, value, _) => screen(
              'Persons',
              next: Builder(
                builder: (context) => TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => screen('Ada')),
                  ),
                  child: Text('open $value'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open 0'));
      await tester.pumpAndSettle();

      expect(titles.last, 'Ada - Heimdall');

      // The offstage parent builds again, after the detail did.
      underneath.value = 1;
      await tester.pump();

      expect(titles.last, 'Ada - Heimdall');

      Navigator.of(tester.element(find.byType(PageTitle).last)).pop();
      await tester.pumpAndSettle();

      expect(titles.last, 'Persons - Heimdall');
    },
  );

  testWidgets('GivenNoNavigator_WhenShown_ThenTheTitleIsStillSet', (
    tester,
  ) async {
    await tester.pumpWidget(
      const PageTitle(
        title: 'Alone',
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(),
        ),
      ),
    );

    expect(titles.last, 'Alone - Heimdall');
  });

  testWidgets('GivenAScreenOnTop_WhenTheAppRebuilds_ThenItsTitleSurvives', (
    tester,
  ) async {
    final mode = ValueNotifier<ThemeMode>(ThemeMode.light);
    await tester.pumpWidget(
      ValueListenableBuilder<ThemeMode>(
        valueListenable: mode,
        builder: (context, value, _) => MaterialApp(
          themeMode: value,
          onGenerateTitle: (_) => PageTitle.currentLabel,
          home: screen('Persons'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    mode.value = ThemeMode.dark;
    await tester.pumpAndSettle();

    // Whatever the application's own title put last is the screen's.
    expect(titles.last, 'Persons - Heimdall');
  });

  testWidgets('GivenTheSameTitle_WhenRebuilt_ThenThePlatformIsToldOnce', (
    tester,
  ) async {
    late StateSetter rebuild;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          rebuild = setState;

          return const PageTitle(
            title: 'Same',
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: SizedBox(),
            ),
          );
        },
      ),
    );
    rebuild(() {});
    await tester.pump();

    expect(titles, <String>['Same - Heimdall']);
  });
}
