import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/core/secrets/screen_security.dart';
import 'package:heimdall_ui/core/secrets/secret_clipboard.dart';
import 'package:heimdall_ui/features/applications/presentation/one_time_secret_dialog.dart';

import '../../../support/secret_fakes.dart';

void main() {
  late RecordingSecretClipboard secrets;
  late RecordingScreenSecurity security;

  setUp(() {
    secrets = RecordingSecretClipboard();
    security = RecordingScreenSecurity();
  });

  Future<void> openDialog(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          secretClipboardProvider.overrideWithValue(secrets),
          screenSecurityProvider.overrideWithValue(security),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showOneTimeSecretDialog(context, 'hds_abcdef'),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'GivenTheSecretDialog_WhenEscapeOrBarrierTapped_ThenItStaysOpen',
    (tester) async {
      // Given
      await openDialog(tester);

      // When
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      // Then
      expect(find.text('hds_abcdef'), findsOneWidget);
    },
  );

  testWidgets('GivenTheSecretDialog_WhenStoredItIsChosen_ThenItCloses', (
    tester,
  ) async {
    // Given
    await openDialog(tester);

    // When
    await tester.tap(find.text("I've stored it"));
    await tester.pumpAndSettle();

    // Then
    expect(find.text('hds_abcdef'), findsNothing);
  });

  testWidgets(
    'GivenTheSecretDialog_WhenCopied_ThenTheSecretIsCopiedForAWhile',
    (tester) async {
      // Given
      await openDialog(tester);

      // When
      await tester.tap(find.text('Copy'));
      await tester.pumpAndSettle();

      // Then
      expect(secrets.copied, <String>['hds_abcdef']);
      expect(find.text('Secret copied.'), findsOneWidget);
    },
  );

  testWidgets(
    'GivenTheSecretDialog_WhenOpenedAndClosed_ThenTheWindowIsSecuredMeanwhile',
    (tester) async {
      // Given
      await openDialog(tester);

      // Then
      expect(security.held, 1);

      // When
      await tester.tap(find.text("I've stored it"));
      await tester.pumpAndSettle();

      // Then
      expect(security.held, 0);
    },
  );
}
