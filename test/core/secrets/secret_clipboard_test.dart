import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/core/secrets/secret_clipboard.dart';

class _FakeClipboard implements ClipboardAccess {
  String? text;
  bool failReads = false;

  @override
  Future<String?> read() async {
    if (failReads) {
      throw StateError('clipboard is not readable');
    }

    return text;
  }

  @override
  Future<void> write(String value) async => text = value;
}

void main() {
  late _FakeClipboard clipboard;
  late SecretClipboard secrets;

  setUp(() {
    clipboard = _FakeClipboard();
    secrets = SecretClipboard(clipboard: clipboard);
  });

  // The delay is the widget binding's fake clock: pump moves it.
  testWidgets(
    'GivenACopiedSecret_WhenTheDelayPasses_ThenTheClipboardIsCleared',
    (tester) async {
      // Given
      unawaited(secrets.copy('hds_secret'));
      await tester.pump();

      // When
      await tester.pump(const Duration(seconds: 61));

      // Then
      expect(clipboard.text, '');
    },
  );

  testWidgets(
    'GivenACopiedSecret_WhenTheDelayHasNotPassed_ThenItIsStillThere',
    (tester) async {
      // Given
      unawaited(secrets.copy('hds_secret'));
      await tester.pump();

      // When
      await tester.pump(const Duration(seconds: 59));

      // Then
      expect(clipboard.text, 'hds_secret');
      await tester.pump(const Duration(seconds: 2));
    },
  );

  testWidgets(
    'GivenSomethingElseWasCopied_WhenTheDelayPasses_ThenItIsLeftAlone',
    (tester) async {
      // Given
      unawaited(secrets.copy('hds_secret'));
      await tester.pump();
      clipboard.text = 'something the person copied later';

      // When
      await tester.pump(const Duration(seconds: 61));

      // Then
      expect(clipboard.text, 'something the person copied later');
    },
  );

  testWidgets('GivenTwoSecrets_WhenTheSecondIsCopied_ThenTheDelayRestarts', (
    tester,
  ) async {
    // Given
    unawaited(secrets.copy('first'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 40));
    unawaited(secrets.copy('second'));
    await tester.pump();

    // When
    await tester.pump(const Duration(seconds: 30));

    // Then
    expect(clipboard.text, 'second');

    await tester.pump(const Duration(seconds: 31));
    expect(clipboard.text, '');
  });

  testWidgets(
    'GivenAClipboardThatCannotBeRead_WhenTheDelayPasses_ThenNothingThrows',
    (tester) async {
      // Given
      unawaited(secrets.copy('hds_secret'));
      await tester.pump();
      clipboard.failReads = true;

      // When
      await tester.pump(const Duration(seconds: 61));

      // Then
      expect(clipboard.text, 'hds_secret');
    },
  );
}
