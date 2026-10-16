import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/core/secrets/screen_security.dart';

const _channel = MethodChannel('heimdall_ui/screen_security');

void main() {
  late List<bool> calls;

  setUp(() {
    calls = <bool>[];
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
          if (call.method == 'setSecure') {
            final arguments = call.arguments as Map<Object?, Object?>;

            calls.add(arguments['secure']! as bool);
          }

          return null;
        });
  });

  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null),
  );

  /// Runs [body] as [platform]; the override has to be gone before the test
  /// ends, which a tearDown is too late for.
  Future<void> on(TargetPlatform platform, Future<void> Function() body) async {
    debugDefaultTargetPlatformOverride = platform;

    try {
      await body();
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }

  Widget app(List<Widget> children) => ProviderScope(
    child: MaterialApp(home: Column(children: children)),
  );

  testWidgets(
    'GivenAnAndroidDevice_WhenASecretIsShown_ThenTheWindowIsSecured',
    (tester) async {
      await on(TargetPlatform.android, () async {
        // When
        await tester.pumpWidget(
          app(const <Widget>[ScreenSecurityGuard(child: Text('secret'))]),
        );

        // Then
        expect(calls, <bool>[true]);
      });
    },
  );

  testWidgets(
    'GivenASecuredWindow_WhenTheSecretLeavesTheScreen_ThenItIsReleased',
    (tester) async {
      await on(TargetPlatform.android, () async {
        // Given
        await tester.pumpWidget(
          app(const <Widget>[ScreenSecurityGuard(child: Text('secret'))]),
        );

        // When
        await tester.pumpWidget(app(const <Widget>[Text('nothing')]));

        // Then
        expect(calls, <bool>[true, false]);
      });
    },
  );

  testWidgets('GivenAnotherPlatform_WhenASecretIsShown_ThenNothingIsSent', (
    tester,
  ) async {
    await on(TargetPlatform.linux, () async {
      // When
      await tester.pumpWidget(
        app(const <Widget>[ScreenSecurityGuard(child: Text('secret'))]),
      );

      // Then
      expect(find.text('secret'), findsOneWidget);
      expect(calls, isEmpty);
    });
  });

  testWidgets(
    'GivenTwoSecretsOnScreen_WhenOneLeaves_ThenTheWindowStaysSecured',
    (tester) async {
      await on(TargetPlatform.android, () async {
        // Given
        await tester.pumpWidget(
          app(const <Widget>[
            ScreenSecurityGuard(key: ValueKey('one'), child: Text('one')),
            ScreenSecurityGuard(key: ValueKey('two'), child: Text('two')),
          ]),
        );

        // When
        await tester.pumpWidget(
          app(const <Widget>[
            ScreenSecurityGuard(key: ValueKey('one'), child: Text('one')),
          ]),
        );

        // Then
        expect(calls, <bool>[true]);
      });
    },
  );
}
