import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/app/theme.dart';
import 'package:heimdall_ui/core/config/app_config.dart';
import 'package:heimdall_ui/core/files/file_saver.dart';
import 'package:heimdall_ui/core/network/dio_client.dart';
import 'package:heimdall_ui/core/result/result.dart';
import 'package:heimdall_ui/core/storage/token_store.dart';
import 'package:heimdall_ui/features/auth/domain/auth_repository.dart';
import 'package:heimdall_ui/features/auth/domain/google_sign_in_gateway.dart';
import 'package:heimdall_ui/features/auth/domain/session.dart';
import 'package:heimdall_ui/features/auth/presentation/session_controller.dart';
import 'package:heimdall_ui/features/data_rights/domain/data_rights.dart';
import 'package:heimdall_ui/features/data_rights/domain/data_rights_repository.dart';
import 'package:heimdall_ui/features/data_rights/presentation/restricted_session_screen.dart';
import 'package:mocktail/mocktail.dart';

class _MockDataRightsRepository extends Mock implements DataRightsRepository {}

class _MockAuthRepository extends Mock implements AuthRepository {}

class _FakeFileSaver implements FileSaver {
  final Map<String, String> saved = <String, String>{};

  /// Whether the file goes to the browser, which reports no path.
  bool toBrowser = false;

  @override
  Future<String?> saveText({
    required String fileName,
    required String contents,
    String mimeType = 'application/json',
  }) async {
    saved[fileName] = contents;

    return toBrowser ? null : '/home/ada/Downloads/$fileName';
  }
}

/// Google's half, faked: the flow is driven by the application and answers
/// with a fresh ID token.
class _FakeGoogleSignInGateway implements GoogleSignInGateway {
  int flows = 0;

  @override
  GoogleSignInAvailability get availability =>
      GoogleSignInAvailability.interactive;

  @override
  Future<void> initialize() async {}

  @override
  Stream<GoogleIdTokenObtained> get idTokens =>
      const Stream<GoogleIdTokenObtained>.empty();

  @override
  Future<GoogleSignInAttempt> obtainIdToken() async {
    flows++;

    return const GoogleIdTokenObtained('fresh-google-token');
  }

  @override
  Future<void> signOut() async {}
}

/// A subject-rights-only token naming Ada.
String _restrictedJwt() {
  final payload = base64Url.encode(
    utf8.encode(
      jsonEncode(<String, dynamic>{
        'id': 'person-1',
        'name': 'Ada Lovelace',
        'role': '3',
        'subjectRightsOnly': 'true',
      }),
    ),
  );

  return 'header.$payload.signature';
}

const Size _compact = Size(400, 900);
const Size _medium = Size(800, 900);
const Size _expanded = Size(1400, 900);

const String _heading = 'Processing of your account is restricted';

void expectDestructive(WidgetTester tester, String confirmLabel) {
  final dialog = find.byType(AlertDialog);
  final scheme = Theme.of(tester.element(dialog)).colorScheme;
  expect(
    tester
        .widget<TextButton>(
          find.descendant(
            of: dialog,
            matching: find.widgetWithText(TextButton, 'Cancel'),
          ),
        )
        .autofocus,
    isTrue,
  );
  expect(
    tester
        .widget<FilledButton>(
          find.descendant(
            of: dialog,
            matching: find.widgetWithText(FilledButton, confirmLabel),
          ),
        )
        .style!
        .backgroundColor!
        .resolve(<WidgetState>{}),
    scheme.error,
  );
}

void main() {
  late _MockDataRightsRepository repository;
  late _FakeFileSaver saver;
  late _FakeGoogleSignInGateway google;
  late InMemoryTokenStore store;
  late ProviderContainer container;

  Future<void> pump(
    WidgetTester tester, {
    Size size = _expanded,
    ThemeData? theme,
    bool viaGoogle = false,
    String? googleClientId,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await store.write(
      AuthToken(
        value: _restrictedJwt(),
        expiresAt: DateTime.utc(2030),
        viaGoogle: viaGoogle,
        processingRestricted: true,
      ),
    );

    container = ProviderContainer(
      overrides: <Override>[
        appConfigProvider.overrideWithValue(
          AppConfig(
            apiBaseUrl: 'http://localhost:8080',
            googleClientId: googleClientId,
          ),
        ),
        dataRightsRepositoryProvider.overrideWithValue(repository),
        fileSaverProvider.overrideWithValue(saver),
        tokenStoreProvider.overrideWithValue(store),
        authRepositoryProvider.overrideWithValue(_MockAuthRepository()),
        googleSignInGatewayProvider.overrideWithValue(google),
      ],
    );
    addTearDown(container.dispose);
    await container.read(sessionControllerProvider.notifier).restore();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: theme ?? buildLightTheme(),
          home: const RestrictedSessionScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapButton(WidgetTester tester, String label) async {
    final button = find
        .ancestor(
          of: find.text(label),
          matching: find.bySubtype<ButtonStyleButton>(),
        )
        .first;
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  setUpAll(() {
    registerFallbackValue(const PasswordCredential(''));
  });

  setUp(() {
    repository = _MockDataRightsRepository();
    saver = _FakeFileSaver();
    google = _FakeGoogleSignInGateway();
    store = InMemoryTokenStore();
  });

  for (final (name, size) in <(String, Size)>[
    ('Compact', _compact),
    ('Medium', _medium),
    ('Expanded', _expanded),
  ]) {
    testWidgets('Given${name}Width_WhenOpened_ThenTheRestrictionIsExplained', (
      tester,
    ) async {
      // Given / When
      await pump(tester, size: size);

      // Then
      expect(find.text(_heading), findsOneWidget);
      expect(find.text('Signed in as Ada Lovelace'), findsOneWidget);
      expect(
        find.textContaining('Only these actions are available'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('GivenTheDarkTheme_WhenOpened_ThenEveryActionIsOffered', (
    tester,
  ) async {
    // Given / When
    await pump(tester, theme: buildDarkTheme());

    // Then
    expect(tester.takeException(), isNull);
    expect(
      find.widgetWithText(FilledButton, 'Lift the restriction'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(OutlinedButton, 'Download my data'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(OutlinedButton, 'Request erasure'),
      findsOneWidget,
    );
    expect(
      find.ancestor(
        of: find.text('Sign out'),
        matching: find.bySubtype<OutlinedButton>(),
      ),
      findsOneWidget,
    );
  });

  // UI-30 main flow.
  testWidgets('GivenTheScreen_WhenLiftConfirmed_ThenTheSessionEnds', (
    tester,
  ) async {
    // Given
    when(() => repository.liftOwnRestriction())
        .thenAnswer((_) async => const Success<void>(null));
    await pump(tester);
    await tapButton(tester, 'Lift the restriction');

    // When
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Lift the restriction'),
      ),
    );
    await tester.pumpAndSettle();

    // Then
    verify(() => repository.liftOwnRestriction()).called(1);
    final session = container.read(sessionControllerProvider);
    expect((session as Unauthenticated).restrictionLifted, isTrue);
  });

  testWidgets('GivenTheLiftDialog_WhenAsked_ThenItIsDestructive', (
    tester,
  ) async {
    // Given
    await pump(tester);

    // When
    await tapButton(tester, 'Lift the restriction');

    // Then a pending erasure goes ahead, so Cancel has the focus
    expectDestructive(tester, 'Lift the restriction');
  });

  testWidgets('GivenTheScreen_WhenLiftCancelled_ThenNothingIsSent', (
    tester,
  ) async {
    // Given
    await pump(tester);
    await tapButton(tester, 'Lift the restriction');

    // When
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    // Then
    verifyNever(() => repository.liftOwnRestriction());
    expect(container.read(sessionControllerProvider), isA<Authenticated>());
  });

  testWidgets('GivenARefusedLift_WhenConfirmed_ThenTheApiErrorsAreShown', (
    tester,
  ) async {
    // Given
    when(() => repository.liftOwnRestriction()).thenAnswer(
      (_) async => const FailureResult<void>(
        Failure(
          kind: FailureKind.server,
          errors: <String>['The restriction could not be lifted.'],
        ),
      ),
    );
    await pump(tester);
    await tapButton(tester, 'Lift the restriction');

    // When
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Lift the restriction'),
      ),
    );
    await tester.pumpAndSettle();

    // Then
    expect(find.text('The restriction could not be lifted.'), findsOneWidget);
  });

  testWidgets('GivenTheScreen_WhenDownloadTapped_ThenWhereItWentIsSaid', (
    tester,
  ) async {
    // Given
    final export = DataExport(
      document: '{"subject": {}}',
      exportedAt: DateTime.utc(2026, 10, 11),
    );
    when(() => repository.exportMyData())
        .thenAnswer((_) async => Success<DataExport>(export));
    await pump(tester);

    // When
    await tapButton(tester, 'Download my data');

    // Then
    expect(saver.saved[export.fileName], '{"subject": {}}');
    expect(
      find.text(
        'Your data was saved to /home/ada/Downloads/${export.fileName}.',
      ),
      findsOneWidget,
    );
  });

  const sensitiveNote =
      'This file holds your personal data and is not encrypted. Keep it '
      'somewhere private, and delete it when you no longer need it.';

  testWidgets('GivenASavedExport_WhenShown_ThenItSaysTheFileIsSensitive', (
    tester,
  ) async {
    // Given
    when(() => repository.exportMyData()).thenAnswer(
      (_) async => Success<DataExport>(
        DataExport(document: '{}', exportedAt: DateTime.utc(2026, 10, 11)),
      ),
    );
    await pump(tester);

    // When
    await tapButton(tester, 'Download my data');

    // Then
    expect(find.text(sensitiveNote), findsOneWidget);
  });

  testWidgets('GivenABrowserDownload_WhenShown_ThenItSaysTheFileIsSensitive', (
    tester,
  ) async {
    // Given
    saver.toBrowser = true;
    when(() => repository.exportMyData()).thenAnswer(
      (_) async => Success<DataExport>(
        DataExport(document: '{}', exportedAt: DateTime.utc(2026, 10, 11)),
      ),
    );
    await pump(tester);

    // When
    await tapButton(tester, 'Download my data');

    // Then
    expect(
      find.text('Your data was handed to your browser as a download.'),
      findsOneWidget,
    );
    expect(find.text(sensitiveNote), findsOneWidget);
  });

  // AF-30c — the API's errors, shown as returned.
  testWidgets('GivenARefusedExport_WhenDownloadTapped_ThenTheErrorsAreShown', (
    tester,
  ) async {
    // Given
    when(() => repository.exportMyData()).thenAnswer(
      (_) async => const FailureResult<DataExport>(
        Failure(
          kind: FailureKind.forbidden,
          errors: <String>['This identity is not eligible.'],
        ),
      ),
    );
    await pump(tester);

    // When
    await tapButton(tester, 'Download my data');

    // Then
    expect(find.text('This identity is not eligible.'), findsOneWidget);
    expect(saver.saved, isEmpty);
  });

  testWidgets('GivenNoConnection_WhenDownloadTapped_ThenItSaysSo', (
    tester,
  ) async {
    // Given
    when(() => repository.exportMyData()).thenAnswer(
      (_) async => const FailureResult<DataExport>(
        Failure(kind: FailureKind.network, errors: <String>[]),
      ),
    );
    await pump(tester);

    // When
    await tapButton(tester, 'Download my data');

    // Then
    expect(find.textContaining('Could not reach the API'), findsOneWidget);
  });

  testWidgets('GivenAPerson_WhenErasureConfirmed_ThenThePasswordIsSent', (
    tester,
  ) async {
    // Given
    when(() => repository.requestErasure(any())).thenAnswer(
      (_) async => Success<ErasureRequest>(
        ErasureRequest(
          requestedAt: DateTime.utc(2026, 10, 11, 12),
          dueAt: DateTime.utc(2026, 11, 10, 12),
        ),
      ),
    );
    await pump(tester);
    await tapButton(tester, 'Request erasure');
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      'secret',
    );
    await tester.pump();

    // When
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Request erasure'),
      ),
    );
    await tester.pumpAndSettle();

    // Then
    final sent =
        verify(() => repository.requestErasure(captureAny())).captured.single
            as PasswordCredential;
    expect(sent.password, 'secret');
    expect(
      find.textContaining('Your erasure request was recorded.'),
      findsOneWidget,
    );
    expect(find.textContaining('November 10, 2026'), findsOneWidget);
  });

  testWidgets('GivenNoPassword_WhenErasureDialogShown_ThenItCannotBeSent', (
    tester,
  ) async {
    // Given
    await pump(tester);

    // When
    await tapButton(tester, 'Request erasure');

    // Then
    final confirm = tester.widget<FilledButton>(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Request erasure'),
      ),
    );
    expect(confirm.onPressed, isNull);
  });

  // AF-30f — recorded, the deadline runs, but the account is not suspended.
  testWidgets('GivenABlockedErasure_WhenRequested_ThenTheReasonIsShown', (
    tester,
  ) async {
    // Given
    when(() => repository.requestErasure(any())).thenAnswer(
      (_) async => const Success<ErasureRequest>(
        ErasureRequest(
          blocked: true,
          blockedReason: 'You are the last owner of a scope.',
        ),
      ),
    );
    await pump(tester);
    await tapButton(tester, 'Request erasure');
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      'secret',
    );
    await tester.pump();

    // When
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Request erasure'),
      ),
    );
    await tester.pumpAndSettle();

    // Then
    expect(
      find.textContaining('You are the last owner of a scope.'),
      findsOneWidget,
    );
  });

  // UC-42 — a Google User confirms with Google, where the app drives the flow.
  testWidgets('GivenAGoogleUser_WhenErasureConfirmed_ThenGoogleIsAsked', (
    tester,
  ) async {
    // Given
    when(
      () => repository.requestErasure(any()),
    ).thenAnswer((_) async => const Success<ErasureRequest>(ErasureRequest()));
    await pump(tester, viaGoogle: true, googleClientId: 'client-id');
    await tapButton(tester, 'Request erasure');

    // When
    await tester.tap(find.widgetWithText(FilledButton, 'Confirm with Google'));
    await tester.pumpAndSettle();

    // Then
    expect(google.flows, 1);
    final sent =
        verify(() => repository.requestErasure(captureAny())).captured.single
            as GoogleIdTokenCredential;
    expect(sent.idToken, 'fresh-google-token');
  });

  testWidgets('GivenTheGoogleErasureDialog_WhenAsked_ThenItIsDestructive', (
    tester,
  ) async {
    // Given
    await pump(tester, viaGoogle: true, googleClientId: 'client-id');

    // When
    await tapButton(tester, 'Request erasure');

    // Then erasure is irreversible
    expectDestructive(tester, 'Confirm with Google');
  });

  // AF-30h — without Google's flow there is no way to confirm it is them.
  testWidgets('GivenAGoogleUserWithoutGoogle_WhenOpened_ThenErasureSaysWhy', (
    tester,
  ) async {
    // Given / When
    await pump(tester, viaGoogle: true);

    // Then
    final request = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Request erasure'),
    );
    expect(request.onPressed, isNull);
    expect(
      find.textContaining('Erasure is confirmed by signing in with Google'),
      findsOneWidget,
    );
  });

  testWidgets('GivenTheScreen_WhenSignOutTapped_ThenTheSessionEnds', (
    tester,
  ) async {
    // Given
    await pump(tester);

    // When
    await tapButton(tester, 'Sign out');

    // Then
    final session = container.read(sessionControllerProvider);
    expect(session, isA<Unauthenticated>());
    expect((session as Unauthenticated).restrictionLifted, isFalse);
  });
}
