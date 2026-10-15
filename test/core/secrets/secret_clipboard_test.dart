import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/core/secrets/secret_clipboard.dart';

class _FakeClipboard implements ClipboardAccess {
  String? text;
  bool failReads = false;
  int reads = 0;

  @override
  Future<String?> read() async {
    reads++;
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
  late DateTime now;

  setUp(() {
    now = DateTime(2026, 10, 15, 12);
    clipboard = _FakeClipboard();
    secrets = SecretClipboard(clipboard: clipboard, now: () => now);
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

  // A backgrounded app may not read the clipboard, or its timer may not run:
  // coming back to the foreground is when the overdue check happens.
  testWidgets(
    'GivenTheDeadlinePassed_WhenTheAppResumes_ThenTheClipboardIsCleared',
    (tester) async {
      // Given
      unawaited(secrets.copy('hds_secret'));
      await tester.pump();
      now = now.add(const Duration(seconds: 61));

      // When
      secrets.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await tester.pump();

      // Then
      expect(clipboard.text, '');
    },
  );

  testWidgets(
    'GivenTheDeadlineNotReached_WhenTheAppResumes_ThenItIsStillThere',
    (tester) async {
      // Given
      unawaited(secrets.copy('hds_secret'));
      await tester.pump();
      now = now.add(const Duration(seconds: 30));

      // When
      secrets.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await tester.pump();

      // Then
      expect(clipboard.text, 'hds_secret');
      await tester.pump(const Duration(seconds: 61));
    },
  );

  testWidgets(
    'GivenAClipboardReadingNull_WhenTheAppResumesLate_ThenNothingIsWritten',
    (tester) async {
      // Given
      unawaited(secrets.copy('hds_secret'));
      await tester.pump();
      clipboard.text = null;
      now = now.add(const Duration(seconds: 61));

      // When
      secrets.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await tester.pump();

      // Then
      expect(clipboard.text, isNull);
    },
  );

  testWidgets('GivenTheWeb_WhenTheDelayPasses_ThenTheClipboardIsNeverRead', (
    tester,
  ) async {
    // Given
    final web = SecretClipboard(
      clipboard: clipboard,
      readable: false,
      now: () => now,
    );
    unawaited(web.copy('hds_secret'));
    await tester.pump();

    // When
    now = now.add(const Duration(seconds: 61));
    await tester.pump(const Duration(seconds: 61));
    web.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await tester.pump();

    // Then
    expect(clipboard.reads, 0);
    expect(clipboard.text, 'hds_secret');
  });

  testWidgets('GivenAClosedApp_WhenTheDelayPasses_ThenNoWorkIsPending', (
    tester,
  ) async {
    // Given
    unawaited(secrets.copy('hds_secret'));
    await tester.pump();

    // When
    secrets.dispose();
    await tester.pump(const Duration(seconds: 61));

    // Then: the test would fail on a pending timer, and nothing was read.
    expect(clipboard.reads, 0);
    expect(clipboard.text, 'hds_secret');
  });
}
