import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/app/theme.dart';
import 'package:heimdall_ui/core/result/result.dart';
import 'package:heimdall_ui/core/storage/token_store.dart';
import 'package:heimdall_ui/features/auth/domain/auth_repository.dart';
import 'package:heimdall_ui/features/auth/domain/session.dart';
import 'package:heimdall_ui/features/auth/presentation/session_controller.dart';
import 'package:heimdall_ui/features/data_rights/domain/data_rights.dart';
import 'package:heimdall_ui/features/data_rights/domain/data_rights_repository.dart';
import 'package:heimdall_ui/features/data_rights/presentation/restrict_processing_dialog.dart';
import 'package:heimdall_ui/shared/widgets/failure_banner.dart';
import 'package:mocktail/mocktail.dart';

import '../../../support/jwt.dart';
import '../../../support/pump_app.dart';

class _MockDataRightsRepository extends Mock implements DataRightsRepository {}

class _MockAuthRepository extends Mock implements AuthRepository {}

/// The three window classes the shell lays out differently.
const Size _compact = Size(400, 900);
const Size _medium = Size(800, 900);
const Size _expanded = Size(1400, 900);

const String _inaccurate = 'I believe my data is inaccurate';
const String _alreadyRestricted =
    'Processing of this account is already restricted.';

void main() {
  late _MockDataRightsRepository repository;
  late InMemoryTokenStore store;
  late ProviderContainer container;

  /// Pumps a page that can open the dialog, signed in with a full session.
  Future<void> host(
    WidgetTester tester, {
    ThemeData? theme,
    Size size = _medium,
  }) async {
    container = await pumpApp(
      tester,
      size: size,
      theme: theme,
      store: store,
      token: testToken(
        testApiJwt(<String, Object?>{'id': 'person-1', 'role': '3'}),
      ),
      overrides: <Override>[
        dataRightsRepositoryProvider.overrideWithValue(repository),
        authRepositoryProvider.overrideWithValue(_MockAuthRepository()),
      ],
      settle: false,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showRestrictProcessingDialog(context),
            child: const Text('Open'),
          ),
        ),
      ),
    );
  }

  Future<void> openDialog(WidgetTester tester) async {
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  Future<void> open(
    WidgetTester tester, {
    ThemeData? theme,
    Size size = _medium,
  }) async {
    await host(tester, theme: theme, size: size);
    await openDialog(tester);
  }

  Finder restrictButton() =>
      find.widgetWithText(FilledButton, 'Restrict processing');

  Finder cancelButton() => find.widgetWithText(TextButton, 'Cancel');

  Future<void> choose(WidgetTester tester, String ground) async {
    await tester.tap(find.text(ground));
    await tester.pump();
  }

  Future<void> confirm(WidgetTester tester) async {
    await tester.tap(restrictButton());
    await tester.pumpAndSettle();
  }

  setUpAll(() {
    registerFallbackValue(RestrictionGround.accuracyContested);
  });

  setUp(() {
    repository = _MockDataRightsRepository();
    store = InMemoryTokenStore();
  });

  testWidgets('GivenTheDialog_WhenOpened_ThenItSaysWhatARestrictionDoes', (
    tester,
  ) async {
    // Given
    await host(tester);

    // When
    await openDialog(tester);

    // Then
    expect(find.text('Restrict processing of your account?'), findsOneWidget);
    expect(
      find.textContaining('your account is suspended until the restriction '),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'You can still sign in to lift the restriction, or to download or '
        'erase your data.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('GivenTheDialog_WhenOpened_ThenTheFourGroundsAreOffered', (
    tester,
  ) async {
    // Given
    await host(tester);

    // When
    await openDialog(tester);

    // Then
    expect(find.text(_inaccurate), findsOneWidget);
    expect(
      find.text(
        'My data is being processed unlawfully, but I do not want it erased',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Heimdall no longer needs my data, but I need it kept for a legal '
        'claim',
      ),
      findsOneWidget,
    );
    expect(
      find.text('I have objected to Heimdall processing my data'),
      findsOneWidget,
    );
    expect(find.byType(RadioListTile<RestrictionGround>), findsNWidgets(4));
  });

  testWidgets('GivenNoGround_WhenOpened_ThenRestrictIsDisabled', (
    tester,
  ) async {
    // Given
    await host(tester);

    // When
    await openDialog(tester);

    // Then
    expect(tester.widget<FilledButton>(restrictButton()).onPressed, isNull);
    final group = tester.widget<RadioGroup<RestrictionGround>>(
      find.byType(RadioGroup<RestrictionGround>),
    );
    expect(group.groupValue, isNull);
  });

  testWidgets('GivenAGround_WhenChosen_ThenRestrictIsEnabled', (tester) async {
    // Given
    await open(tester);

    // When
    await choose(tester, _inaccurate);

    // Then
    expect(tester.widget<FilledButton>(restrictButton()).onPressed, isNotNull);
    verifyNever(() => repository.restrictProcessing(any()));
  });

  // AF-33a
  testWidgets('GivenAGround_WhenCancelled_ThenNothingIsSent', (tester) async {
    // Given
    await open(tester);
    await choose(tester, _inaccurate);

    // When
    await tester.tap(cancelButton());
    await tester.pumpAndSettle();

    // Then
    expect(find.byType(AlertDialog), findsNothing);
    verifyNever(() => repository.restrictProcessing(any()));
    expect(container.read(sessionControllerProvider), isA<Authenticated>());
  });

  // UI-33 main flow.
  testWidgets('GivenAGround_WhenConfirmed_ThenTheSessionEndsWithTheReason', (
    tester,
  ) async {
    // Given
    when(() => repository.restrictProcessing(any()))
        .thenAnswer((_) async => const Success<void>(null));
    await open(tester);
    await choose(tester, _inaccurate);

    // When
    await confirm(tester);

    // Then
    verify(
      () => repository.restrictProcessing(RestrictionGround.accuracyContested),
    ).called(1);
    expect(find.byType(AlertDialog), findsNothing);
    final session = container.read(sessionControllerProvider);
    expect((session as Unauthenticated).processingRestricted, isTrue);
  });

  // AF-33b
  testWidgets(
    'GivenAnAlreadyRestrictedAccount_WhenConfirmed_ThenTheApiSaysSo',
    (tester) async {
      // Given
      when(() => repository.restrictProcessing(any())).thenAnswer(
        (_) async => const FailureResult<void>(
          Failure(
            kind: FailureKind.conflict,
            errors: <String>[_alreadyRestricted],
          ),
        ),
      );
      await open(tester);
      await choose(tester, _inaccurate);

      // When
      await confirm(tester);

      // Then
      expect(find.text(_alreadyRestricted), findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Sign out'), findsOneWidget);
      expect(restrictButton(), findsNothing);
      expect(cancelButton(), findsNothing);
      expect(container.read(sessionControllerProvider), isA<Authenticated>());
    },
  );

  // AF-33b — the session is already refused elsewhere, so it cannot be kept
  // by walking away from the dialog.
  testWidgets(
    'GivenAnAlreadyRestrictedAccount_WhenDismissed_ThenTheDialogStays',
    (tester) async {
      // Given
      when(() => repository.restrictProcessing(any())).thenAnswer(
        (_) async => const FailureResult<void>(
          Failure(
            kind: FailureKind.conflict,
            errors: <String>[_alreadyRestricted],
          ),
        ),
      );
      await open(tester);
      await choose(tester, _inaccurate);
      await confirm(tester);

      // When
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      // Then
      expect(find.byType(AlertDialog), findsOneWidget);
    },
  );

  // AF-33b — signing out ends the session with the UI-33 reason.
  testWidgets(
    'GivenAnAlreadyRestrictedAccount_WhenSignedOut_ThenTheReasonIsKept',
    (tester) async {
      // Given
      when(() => repository.restrictProcessing(any())).thenAnswer(
        (_) async => const FailureResult<void>(
          Failure(
            kind: FailureKind.conflict,
            errors: <String>[_alreadyRestricted],
          ),
        ),
      );
      await open(tester);
      await choose(tester, _inaccurate);
      await confirm(tester);

      // When
      await tester.tap(find.widgetWithText(FilledButton, 'Sign out'));
      await tester.pumpAndSettle();

      // Then
      expect(find.byType(AlertDialog), findsNothing);
      final session = container.read(sessionControllerProvider);
      expect((session as Unauthenticated).processingRestricted, isTrue);
      verify(() => repository.restrictProcessing(any())).called(1);
    },
  );

  // AF-33c
  testWidgets('GivenARefusal_WhenConfirmed_ThenTheApiErrorsAreShown', (
    tester,
  ) async {
    // Given
    when(() => repository.restrictProcessing(any())).thenAnswer(
      (_) async => const FailureResult<void>(
        Failure(
          kind: FailureKind.validation,
          errors: <String>['RestrictionGroundUnknown'],
        ),
      ),
    );
    await open(tester);
    await choose(tester, _inaccurate);

    // When
    await confirm(tester);

    // Then
    expect(find.text('RestrictionGroundUnknown'), findsOneWidget);
    expect(tester.widget<FilledButton>(restrictButton()).onPressed, isNotNull);
  });

  // AF-33d
  testWidgets('GivenATransportFailure_WhenConfirmed_ThenItSaysSo', (
    tester,
  ) async {
    // Given
    when(() => repository.restrictProcessing(any())).thenAnswer(
      (_) async => const FailureResult<void>(
        Failure(kind: FailureKind.network, errors: <String>[]),
      ),
    );
    await open(tester);
    await choose(tester, _inaccurate);

    // When
    await confirm(tester);

    // Then
    expect(find.byType(ErrorBanner), findsOneWidget);
    expect(
      find.text(
        'Could not reach the API. Check your connection and try again.',
      ),
      findsOneWidget,
    );
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('GivenARequestInFlight_WhenDismissed_ThenTheDialogStays', (
    tester,
  ) async {
    // Given
    final pending = Completer<Result<void>>();
    when(() => repository.restrictProcessing(any()))
        .thenAnswer((_) => pending.future);
    await open(tester);
    await choose(tester, _inaccurate);
    await tester.tap(restrictButton());
    await tester.pump();

    // When
    await tester.tapAt(const Offset(5, 5));
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pump();

    // Then
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(tester.widget<TextButton>(cancelButton()).onPressed, isNull);
    expect(tester.widget<FilledButton>(restrictButton()).onPressed, isNull);

    pending.complete(const Success<void>(null));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('GivenTheCompactWidth_WhenOpened_ThenItRenders', (tester) async {
    // Given
    await host(tester, size: _compact);

    // When
    await openDialog(tester);

    // Then
    expect(find.text('Restrict processing of your account?'), findsOneWidget);
    expect(find.byType(RadioListTile<RestrictionGround>), findsNWidgets(4));
    expect(tester.takeException(), isNull);
  });

  testWidgets('GivenTheMediumWidth_WhenOpened_ThenItRenders', (tester) async {
    // Given
    await host(tester, size: _medium);

    // When
    await openDialog(tester);

    // Then
    expect(find.text('Restrict processing of your account?'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('GivenTheExpandedWidth_WhenOpened_ThenItRenders', (tester) async {
    // Given
    await host(tester, size: _expanded);

    // When
    await openDialog(tester);

    // Then
    expect(find.text('Restrict processing of your account?'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('GivenTheDarkTheme_WhenOpened_ThenItRenders', (tester) async {
    // Given
    await host(tester, theme: buildDarkTheme());

    // When
    await openDialog(tester);

    // Then
    expect(find.text('Restrict processing of your account?'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
