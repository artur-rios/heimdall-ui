import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/core/files/file_saver.dart';
import 'package:heimdall_ui/core/result/result.dart';
import 'package:heimdall_ui/core/storage/token_store.dart';
import 'package:heimdall_ui/features/auth/domain/auth_repository.dart';
import 'package:heimdall_ui/features/auth/domain/google_sign_in_gateway.dart';
import 'package:heimdall_ui/features/auth/domain/session.dart';
import 'package:heimdall_ui/features/auth/presentation/session_controller.dart';
import 'package:heimdall_ui/features/data_rights/domain/data_rights.dart';
import 'package:heimdall_ui/features/data_rights/domain/data_rights_repository.dart';
import 'package:heimdall_ui/features/data_rights/presentation/restricted_session_controller.dart';
import 'package:mocktail/mocktail.dart';

class _MockDataRightsRepository extends Mock implements DataRightsRepository {}

class _MockAuthRepository extends Mock implements AuthRepository {}

/// Keeps what it was asked to save, in memory.
class _FakeFileSaver implements FileSaver {
  _FakeFileSaver({this.answer = '/downloads/export.json', this.error});

  final String? answer;
  final Object? error;
  final Map<String, String> saved = <String, String>{};

  @override
  Future<String?> saveText({
    required String fileName,
    required String contents,
    String mimeType = 'application/json',
  }) async {
    if (error case final Object error) {
      throw error;
    }

    saved[fileName] = contents;

    return answer;
  }
}

/// Google's half, faked: answers the flow with [attempt].
class _FakeGoogleSignInGateway implements GoogleSignInGateway {
  _FakeGoogleSignInGateway(this.attempt);

  final GoogleSignInAttempt attempt;

  @override
  GoogleSignInAvailability get availability =>
      GoogleSignInAvailability.interactive;

  @override
  Future<void> initialize() async {}

  @override
  Stream<GoogleIdTokenObtained> get idTokens =>
      const Stream<GoogleIdTokenObtained>.empty();

  @override
  Future<GoogleSignInAttempt> obtainIdToken() async => attempt;

  @override
  Future<void> signOut() async {}
}

/// A subject-rights-only token, shaped as the API mints one.
String _restrictedJwt() {
  String segment(Map<String, Object> json) =>
      base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');

  return '${segment(<String, Object>{'alg': 'HS256'})}.'
      '${segment(<String, Object>{'id': 'person-1', 'role': '3', 'subjectRightsOnly': 'true'})}.'
      'signature';
}

const Failure _refused = Failure(
  kind: FailureKind.forbidden,
  errors: <String>['This identity is not eligible.'],
);

void main() {
  late _MockDataRightsRepository repository;
  late _FakeFileSaver saver;
  late InMemoryTokenStore store;

  Future<ProviderContainer> containerWith({
    GoogleSignInAttempt google = const GoogleSignInCancelled(),
    bool viaGoogle = false,
  }) async {
    await store.write(
      AuthToken(
        value: _restrictedJwt(),
        expiresAt: DateTime.utc(2030),
        viaGoogle: viaGoogle,
        processingRestricted: true,
      ),
    );
    final container = ProviderContainer(
      overrides: <Override>[
        dataRightsRepositoryProvider.overrideWithValue(repository),
        fileSaverProvider.overrideWithValue(saver),
        tokenStoreProvider.overrideWithValue(store),
        authRepositoryProvider.overrideWithValue(_MockAuthRepository()),
        googleSignInGatewayProvider.overrideWithValue(
          _FakeGoogleSignInGateway(google),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(sessionControllerProvider.notifier).restore();
    // Keep the controller alive for the whole test.
    container.listen(restrictedSessionControllerProvider, (_, _) {});

    return container;
  }

  RestrictedSessionController controllerOf(ProviderContainer container) =>
      container.read(restrictedSessionControllerProvider.notifier);

  RestrictedSessionState stateOf(ProviderContainer container) =>
      container.read(restrictedSessionControllerProvider);

  setUpAll(() {
    // `any()` needs a value of the credential type to stand in for.
    registerFallbackValue(const PasswordCredential(''));
  });

  setUp(() {
    repository = _MockDataRightsRepository();
    saver = _FakeFileSaver();
    store = InMemoryTokenStore();
  });

  // UI-30 main flow — lifted, then signed out to sign in again in full.
  test(
    'GivenARestriction_WhenLifted_ThenTheSessionEndsWithTheReason',
    () async {
      // Given
      when(() => repository.liftOwnRestriction())
          .thenAnswer((_) async => const Success<void>(null));
      final container = await containerWith();

      // When
      await controllerOf(container).liftRestriction();

      // Then
      final session = container.read(sessionControllerProvider);
      expect((session as Unauthenticated).restrictionLifted, isTrue);
      expect(await store.read(), isNull);
    },
  );

  test('GivenARefusedLift_WhenLifted_ThenTheErrorsAreKept', () async {
    // Given
    when(() => repository.liftOwnRestriction())
        .thenAnswer((_) async => const FailureResult<void>(_refused));
    final container = await containerWith();

    // When
    await controllerOf(container).liftRestriction();

    // Then
    expect(stateOf(container).failure?.errors, _refused.errors);
    expect(stateOf(container).busy, isNull);
    expect(container.read(sessionControllerProvider), isA<Authenticated>());
  });

  // AF-30b — lifted elsewhere already; what the person wanted holds.
  test('GivenAnAlreadyLiftedRestriction_WhenLifted_ThenItEndsAlike', () async {
    // Given
    when(() => repository.liftOwnRestriction()).thenAnswer(
      (_) async => const FailureResult<void>(
        Failure(kind: FailureKind.notFound, errors: <String>['Not found.']),
      ),
    );
    final container = await containerWith();

    // When
    await controllerOf(container).liftRestriction();

    // Then
    final session = container.read(sessionControllerProvider);
    expect((session as Unauthenticated).restrictionLifted, isTrue);
  });

  test('GivenAnExport_WhenExported_ThenItIsSavedUnderItsName', () async {
    // Given
    final export = DataExport(
      document: '{"subject": {}}',
      exportedAt: DateTime.utc(2026, 10, 11, 8),
    );
    when(() => repository.exportMyData())
        .thenAnswer((_) async => Success<DataExport>(export));
    final container = await containerWith();

    // When
    await controllerOf(container).exportData();

    // Then
    expect(saver.saved[export.fileName], '{"subject": {}}');
    expect(stateOf(container).exported, isTrue);
    expect(stateOf(container).exportedTo, '/downloads/export.json');
  });

  // On the web the browser decides where a download goes.
  test('GivenTheBrowser_WhenExported_ThenNoPathIsKept', () async {
    // Given
    saver = _FakeFileSaver(answer: null);
    when(() => repository.exportMyData()).thenAnswer(
      (_) async => const Success<DataExport>(DataExport(document: '{}')),
    );
    final container = await containerWith();

    // When
    await controllerOf(container).exportData();

    // Then
    expect(stateOf(container).exported, isTrue);
    expect(stateOf(container).exportedTo, isNull);
  });

  // AF-30c.
  test('GivenARefusedExport_WhenExported_ThenNothingIsSaved', () async {
    // Given
    when(() => repository.exportMyData())
        .thenAnswer((_) async => const FailureResult<DataExport>(_refused));
    final container = await containerWith();

    // When
    await controllerOf(container).exportData();

    // Then
    expect(saver.saved, isEmpty);
    expect(stateOf(container).failure?.errors, _refused.errors);
    expect(stateOf(container).exported, isFalse);
  });

  // AF-30d — the API answered, but the device would not keep the file.
  test('GivenAFileThatCannotBeSaved_WhenExported_ThenItIsSaid', () async {
    // Given
    saver = _FakeFileSaver(error: const _DiskFull());
    when(() => repository.exportMyData()).thenAnswer(
      (_) async => const Success<DataExport>(DataExport(document: '{}')),
    );
    final container = await containerWith();

    // When
    await controllerOf(container).exportData();

    // Then
    expect(
      stateOf(container).failure?.errors.single,
      startsWith('Your data could not be saved'),
    );
    expect(stateOf(container).exported, isFalse);
  });

  test('GivenAPassword_WhenErasureRequested_ThenTheOutcomeIsKept', () async {
    // Given
    const credential = PasswordCredential('secret');
    when(() => repository.requestErasure(credential)).thenAnswer(
      (_) async => Success<ErasureRequest>(
        ErasureRequest(dueAt: DateTime.utc(2026, 11, 10)),
      ),
    );
    final container = await containerWith();

    // When
    await controllerOf(container).requestErasure(credential);

    // Then
    expect(stateOf(container).erasure?.dueAt, DateTime.utc(2026, 11, 10));
    expect(stateOf(container).failure, isNull);
  });

  // AF-30e — the API's own words for a wrong password.
  test(
    'GivenAWrongPassword_WhenErasureRequested_ThenTheErrorsAreKept',
    () async {
      // Given
      const credential = PasswordCredential('wrong');
      when(() => repository.requestErasure(credential)).thenAnswer(
        (_) async => const FailureResult<ErasureRequest>(
          Failure(
            kind: FailureKind.validation,
            errors: <String>['The credential presented was not accepted.'],
          ),
        ),
      );
      final container = await containerWith();

      // When
      await controllerOf(container).requestErasure(credential);

      // Then
      expect(stateOf(container).failure?.errors, <String>[
        'The credential presented was not accepted.',
      ]);
      expect(stateOf(container).erasure, isNull);
      expect(container.read(sessionControllerProvider), isA<Authenticated>());
    },
  );

  // UC-42 step 1 — a Google User confirms with a token Google just issued.
  test('GivenAGoogleUser_WhenErasureConfirmed_ThenTheIdTokenIsSent', () async {
    // Given
    const credential = GoogleIdTokenCredential('fresh-google-token');
    when(
      () => repository.requestErasure(any()),
    ).thenAnswer((_) async => const Success<ErasureRequest>(ErasureRequest()));
    final container = await containerWith(
      google: const GoogleIdTokenObtained('fresh-google-token'),
      viaGoogle: true,
    );

    // When
    await controllerOf(container).requestErasureWithGoogle();

    // Then
    final sent =
        verify(() => repository.requestErasure(captureAny())).captured.single
            as GoogleIdTokenCredential;
    expect(sent.idToken, credential.idToken);
  });

  test(
    'GivenACancelledGoogleFlow_WhenErasureRequested_ThenNothingIsSent',
    () async {
      // Given
      final container = await containerWith(viaGoogle: true);

      // When
      await controllerOf(container).requestErasureWithGoogle();

      // Then
      verifyNever(() => repository.requestErasure(any()));
      expect(stateOf(container).failure, isNull);
    },
  );

  test('GivenAnActionInFlight_WhenAnotherIsStarted_ThenItIsIgnored', () async {
    // Given
    final pending = Completer<Result<DataExport>>();
    when(() => repository.exportMyData()).thenAnswer((_) => pending.future);
    final container = await containerWith();
    final export = controllerOf(container).exportData();

    // When
    await controllerOf(container).liftRestriction();

    // Then
    verifyNever(() => repository.liftOwnRestriction());
    expect(stateOf(container).busy, RestrictedSessionAction.exporting);
    pending.complete(const FailureResult<DataExport>(_refused));
    await export;
  });

  // The next session on this device may be somebody else's.
  test('GivenAnOutcome_WhenTheSessionEnds_ThenItIsForgotten', () async {
    // Given
    when(() => repository.exportMyData()).thenAnswer(
      (_) async => const Success<DataExport>(DataExport(document: '{}')),
    );
    final container = await containerWith();
    await controllerOf(container).exportData();

    // When
    await container.read(sessionControllerProvider.notifier).signOut();

    // Then
    expect(stateOf(container).exported, isFalse);
  });

  // An erasure answered after the session ended belongs to that session, not
  // to whoever signs in next on the device.
  test(
    'GivenAnErasureInFlight_WhenTheSessionEnds_ThenTheAnswerIsDropped',
    () async {
      // Given
      const credential = PasswordCredential('secret');
      final answer = Completer<Result<ErasureRequest>>();
      when(() => repository.requestErasure(credential))
          .thenAnswer((_) => answer.future);
      final container = await containerWith();
      final pending = controllerOf(container).requestErasure(credential);

      // When
      await container.read(sessionControllerProvider.notifier).signOut();
      answer.complete(
        Success<ErasureRequest>(
          ErasureRequest(dueAt: DateTime.utc(2026, 11, 10)),
        ),
      );
      await pending;

      // Then
      expect(stateOf(container).erasure, isNull);
      expect(stateOf(container).busy, isNull);
    },
  );

  // The same for an export: where the previous person's data was saved is
  // nobody else's business.
  test(
    'GivenAnExportInFlight_WhenTheSessionEnds_ThenTheAnswerIsDropped',
    () async {
      // Given
      final answer = Completer<Result<DataExport>>();
      when(() => repository.exportMyData()).thenAnswer((_) => answer.future);
      final container = await containerWith();
      final pending = controllerOf(container).exportData();

      // When
      await container.read(sessionControllerProvider.notifier).signOut();
      answer.complete(const Success<DataExport>(DataExport(document: '{}')));
      await pending;

      // Then
      expect(stateOf(container).exported, isFalse);
      expect(stateOf(container).exportedTo, isNull);
      expect(saver.saved, isEmpty);
    },
  );
}

/// What a file system refusing the write looks like from here.
class _DiskFull implements Exception {
  const _DiskFull();

  @override
  String toString() => 'the disk is full';
}
