import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:heimdall_ui/app/theme.dart';
import 'package:heimdall_ui/features/privacy/domain/privacy_notice.dart';
import 'package:heimdall_ui/features/privacy/presentation/privacy_notice_screen.dart';

/// An asset bundle that has nothing, standing in for a build that lost the
/// notice.
class _EmptyBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) =>
      Future<ByteData>.error(FlutterError('no asset $key'));
}

void main() {
  // Read from the bundled file rather than written out, so refreshing the
  // notice to a new version does not break these tests.
  final versionLine = RegExp(
    r'^\*\*(Version [^*]+)\*\*$',
    multiLine: true,
  ).firstMatch(File(privacyNoticeAsset).readAsStringSync())!.group(1)!;

  late List<Uri> opened;

  setUp(() {
    opened = <Uri>[];
    // rootBundle caches the load as a future of the test that made it, whose
    // fake clock has stopped by the next test — which would then wait on it
    // forever.
    rootBundle.clear();
  });

  Future<void> pump(
    WidgetTester tester, {
    Size size = const Size(400, 900),
    ThemeData? theme,
    List<String> history = const <String>['/privacy'],
    AssetBundle? bundle,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final router = GoRouter(
      initialLocation: history.first,
      routes: <RouteBase>[
        GoRoute(path: '/', builder: (context, state) => const Text('home')),
        GoRoute(
          path: '/login',
          builder: (context, state) => const Text('login'),
        ),
        GoRoute(
          path: '/privacy',
          builder: (context, state) => PrivacyNoticeScreen(
            openLink: (uri) async {
              opened.add(uri);

              return true;
            },
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    final app = MaterialApp.router(
      theme: theme ?? buildLightTheme(),
      routerConfig: router,
    );

    await tester.pumpWidget(
      bundle == null ? app : DefaultAssetBundle(bundle: bundle, child: app),
    );
    await tester.pumpAndSettle();

    for (final location in history.skip(1)) {
      unawaited(router.push(location));
      await tester.pumpAndSettle();
    }
  }

  Finder textContaining(String text) =>
      find.textContaining(text, findRichText: true);

  testWidgets('GivenCompactWidth_WhenOpened_ThenTheNoticeAndVersionAreShown', (
    tester,
  ) async {
    // Given / When
    await pump(tester, size: const Size(400, 900));

    // Then
    expect(find.text('Privacy notice'), findsOneWidget);
    expect(textContaining(versionLine), findsOneWidget);
    expect(textContaining('Who is responsible'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('GivenMediumWidth_WhenOpened_ThenTheNoticeAndVersionAreShown', (
    tester,
  ) async {
    // Given / When
    await pump(tester, size: const Size(800, 900));

    // Then
    expect(textContaining(versionLine), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('GivenExpandedWidth_WhenOpened_ThenTheTextKeepsAReadableWidth', (
    tester,
  ) async {
    // Given / When
    await pump(tester, size: const Size(1400, 900));

    // Then
    expect(textContaining(versionLine), findsOneWidget);
    expect(
      tester.getSize(find.byType(MarkdownBody)).width,
      lessThanOrEqualTo(PrivacyNoticeScreen.maxContentWidth),
    );
    expect(tester.takeException(), isNull);
  });

  // Three columns share a phone's width, so the cells give up some padding.
  testWidgets('GivenCompactWidth_WhenOpened_ThenTableCellsArePaddedLess', (
    tester,
  ) async {
    // Given / When
    await pump(tester, size: const Size(400, 900));
    final compact = tester
        .widget<MarkdownBody>(find.byType(MarkdownBody))
        .styleSheet!
        .tableCellsPadding!;
    await pump(tester, size: const Size(1400, 900));
    final expanded = tester
        .widget<MarkdownBody>(find.byType(MarkdownBody))
        .styleSheet!
        .tableCellsPadding!;

    // Then
    expect(compact.horizontal, lessThan(expanded.horizontal));
  });

  testWidgets('GivenDarkTheme_WhenOpened_ThenTheNoticeIsShown', (tester) async {
    // Given / When
    await pump(tester, theme: buildDarkTheme());

    // Then
    expect(textContaining(versionLine), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // The renderer's own link colour is a fixed blue, which reads poorly on the
  // dark surface.
  testWidgets('GivenDarkTheme_WhenOpened_ThenLinksTakeThePrimaryColour', (
    tester,
  ) async {
    // Given
    final theme = buildDarkTheme();

    // When
    await pump(tester, theme: theme);

    // Then
    final markdown = tester.widget<MarkdownBody>(find.byType(MarkdownBody));
    expect(markdown.styleSheet?.a?.color, theme.colorScheme.primary);
  });

  testWidgets('GivenTheFrontMatter_WhenOpened_ThenItIsNotShown', (
    tester,
  ) async {
    // Given / When
    await pump(tester);

    // Then
    expect(textContaining('linkTitle'), findsNothing);
  });

  testWidgets('GivenASiblingDocumentLink_WhenTapped_ThenTheApiCopyOpens', (
    tester,
  ) async {
    // Given
    await pump(tester);
    final markdown = tester.widget<MarkdownBody>(find.byType(MarkdownBody));

    // When
    markdown.onTapLink!(
      'Data Protection Document',
      'Data%20Protection%20Document.md',
      '',
    );

    // Then
    expect(opened, <Uri>[
      Uri.parse(
        'https://github.com/artur-rios/heimdall-api/blob/main/docs/'
        'requirements/Data%20Protection%20Document.md',
      ),
    ]);
  });

  // Reached from Google's consent screen, the page is the first one opened, so
  // there is nothing to pop back to.
  testWidgets('GivenNoHistory_WhenBackIsTapped_ThenTheAppIsOpened', (
    tester,
  ) async {
    // Given
    await pump(tester);

    // When
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    // Then
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('GivenOpenedFromLogin_WhenBackIsTapped_ThenLoginIsShownAgain', (
    tester,
  ) async {
    // Given
    await pump(tester, history: const <String>['/login', '/privacy']);

    // When
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    // Then
    expect(find.text('login'), findsOneWidget);
  });

  testWidgets('GivenTheNoticeIsMissing_WhenOpened_ThenItSaysSo', (
    tester,
  ) async {
    // Given / When
    await pump(tester, bundle: _EmptyBundle());

    // Then
    expect(
      find.text('The privacy notice could not be loaded.'),
      findsOneWidget,
    );
  });
}
