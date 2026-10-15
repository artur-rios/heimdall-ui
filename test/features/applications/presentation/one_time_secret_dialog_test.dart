import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/features/applications/presentation/one_time_secret_dialog.dart';

void main() {
  Future<void> openDialog(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showOneTimeSecretDialog(context, 'hds_abcdef'),
              child: const Text('open'),
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

  testWidgets('GivenTheSecretDialog_WhenCopied_ThenTheSecretIsOnTheClipboard', (
    tester,
  ) async {
    // Given
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map<Object?, Object?>)['text'] as String?;
        }

        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await openDialog(tester);

    // When
    await tester.tap(find.text('Copy'));
    await tester.pumpAndSettle();

    // Then
    expect(copied, 'hds_abcdef');
    expect(find.text('Secret copied.'), findsOneWidget);
  });
}
