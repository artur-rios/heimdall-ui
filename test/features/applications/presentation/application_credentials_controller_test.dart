import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/core/result/result.dart';
import 'package:heimdall_ui/features/applications/domain/application_credential.dart';
import 'package:heimdall_ui/features/applications/domain/application_credential_repository.dart';
import 'package:heimdall_ui/features/applications/presentation/application_credentials_controller.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepository extends Mock implements ApplicationCredentialRepository {}

const CredentialsKey _key = (scopeId: 's1', applicationId: 'a1');

ApplicationCredential _live(String id) =>
    ApplicationCredential(id: id, live: true);

void main() {
  late _MockRepository repository;
  late ProviderContainer container;
  ProviderSubscription<CredentialsState>? subscription;

  void answerListWith(Result<List<ApplicationCredential>> result) {
    when(() => repository.list('s1', 'a1')).thenAnswer((_) async => result);
  }

  ApplicationCredentialsController controllerUnderTest() {
    container = ProviderContainer(
      overrides: <Override>[
        applicationCredentialRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    // An auto-disposed provider needs a listener to stay alive.
    subscription = container.listen(
      applicationCredentialsControllerProvider(_key),
      (_, _) {},
    );

    return container.read(
      applicationCredentialsControllerProvider(_key).notifier,
    );
  }

  CredentialsState currentState() =>
      container.read(applicationCredentialsControllerProvider(_key));

  setUp(() {
    repository = _MockRepository();
    subscription = null;
  });

  test('GivenTwoLiveCredentials_WhenLoaded_ThenIssuingIsNotOffered', () async {
    // Given
    answerListWith(
      Success<List<ApplicationCredential>>(<ApplicationCredential>[
        _live('c1'),
        _live('c2'),
      ]),
    );
    final controller = controllerUnderTest();

    // When
    await controller.load();

    // Then
    expect(currentState().liveCount, 2);
    expect(currentState().mayIssue, isFalse);
  });

  test('GivenTheLimitWasReachedMeanwhile_WhenIssuing_ThenTheMessageShowsAndTheListReloads', () async {
    // Given — one live when loaded; another admin issued a second since
    answerListWith(
      Success<List<ApplicationCredential>>(<ApplicationCredential>[
        _live('c1'),
      ]),
    );
    final controller = controllerUnderTest();
    await controller.load();
    answerListWith(
      Success<List<ApplicationCredential>>(<ApplicationCredential>[
        _live('c1'),
        _live('c2'),
      ]),
    );
    when(() => repository.issue('s1', 'a1', expiresAt: any(named: 'expiresAt')))
        .thenAnswer(
          (_) async => const FailureResult<IssuedCredential>(
            Failure(
              kind: FailureKind.conflict,
              errors: <String>[
                'This application already has two live credentials. Revoke one before issuing another.',
              ],
            ),
          ),
        );

    // When
    final result = await controller.issue();

    // Then
    expect(result!.isSuccess, isFalse);
    expect(
      currentState().actionFailure!.errors.single,
      startsWith('This application already has two live credentials.'),
    );
    expect(currentState().liveCount, 2);
  });

  test('GivenAnIssue_WhenItSucceeds_ThenTheSecretIsReturnedButNotKeptAndTheListReloads', () async {
    // Given
    answerListWith(
      const Success<List<ApplicationCredential>>(<ApplicationCredential>[]),
    );
    final controller = controllerUnderTest();
    await controller.load();
    answerListWith(
      Success<List<ApplicationCredential>>(<ApplicationCredential>[
        _live('c3'),
      ]),
    );
    when(() => repository.issue('s1', 'a1', expiresAt: any(named: 'expiresAt')))
        .thenAnswer(
          (_) async => const Success<IssuedCredential>(
            IssuedCredential(id: 'c3', secret: 'hds_secret'),
          ),
        );

    // When
    final result = await controller.issue();

    // Then
    expect(result!.valueOrNull!.secret, 'hds_secret');
    expect(currentState().credentials!.single.id, 'c3');
    expect(currentState().toString(), isNot(contains('hds_secret')));
    expect(currentState().busy, isFalse);
    expect(currentState().actionFailure, isNull);
  });

  test(
    'GivenALiveCredential_WhenRevoked_ThenTheListReloadsWithANotice',
    () async {
      // Given
      answerListWith(
        Success<List<ApplicationCredential>>(<ApplicationCredential>[
          _live('c1'),
        ]),
      );
      final controller = controllerUnderTest();
      await controller.load();
      when(() => repository.revoke('s1', 'a1', 'c1'))
          .thenAnswer((_) async => const Success<void>(null));

      // When
      await controller.revoke(_live('c1'));

      // Then
      expect(currentState().notice, 'Credential revoked.');
      verify(() => repository.list('s1', 'a1')).called(2);
    },
  );

  test('GivenAnAlreadyRevokedCredential_WhenRevoked_ThenTheMessageShowsAndTheListReloads', () async {
    // Given — AF-37d
    answerListWith(
      Success<List<ApplicationCredential>>(<ApplicationCredential>[
        _live('c1'),
      ]),
    );
    final controller = controllerUnderTest();
    await controller.load();
    when(() => repository.revoke('s1', 'a1', 'c1')).thenAnswer(
      (_) async => const FailureResult<void>(
        Failure(
          kind: FailureKind.conflict,
          errors: <String>['This application credential is already revoked.'],
        ),
      ),
    );

    // When
    await controller.revoke(_live('c1'));

    // Then
    expect(
      currentState().actionFailure!.errors.single,
      'This application credential is already revoked.',
    );
    verify(() => repository.list('s1', 'a1')).called(2);
  });

  test('GivenALoadFailure_WhenLoaded_ThenTheFailureIsKept', () async {
    // Given
    answerListWith(
      const FailureResult<List<ApplicationCredential>>(
        Failure(kind: FailureKind.network, errors: <String>[]),
      ),
    );
    final controller = controllerUnderTest();

    // When
    await controller.load();

    // Then
    expect(currentState().loadFailure!.kind, FailureKind.network);
    expect(currentState().credentials, isNull);
  });

  test('GivenAnOutcomeShown_WhenTheProviderIsDisposedAndReadAgain_ThenTheStateIsFresh', () async {
    // Given
    answerListWith(
      Success<List<ApplicationCredential>>(<ApplicationCredential>[
        _live('c1'),
      ]),
    );
    final controller = controllerUnderTest();
    await controller.load();
    when(() => repository.revoke('s1', 'a1', 'c1'))
        .thenAnswer((_) async => const Success<void>(null));
    await controller.revoke(_live('c1'));
    expect(currentState().notice, isNotNull);

    // When
    subscription!.close();
    await Future<void>.delayed(Duration.zero);

    // Then
    final fresh = container.read(
      applicationCredentialsControllerProvider(_key),
    );
    expect(fresh.notice, isNull);
    expect(fresh.credentials, isNull);
  });

  test('GivenAnIssueInFlight_WhenTheProviderIsDisposedBeforeItCompletes_ThenNothingThrows', () async {
    // Given
    answerListWith(
      const Success<List<ApplicationCredential>>(<ApplicationCredential>[]),
    );
    final pending = Completer<Result<IssuedCredential>>();
    when(() => repository.issue('s1', 'a1', expiresAt: any(named: 'expiresAt')))
        .thenAnswer((_) => pending.future);
    final controller = controllerUnderTest();
    final issuing = controller.issue();
    subscription!.close();
    await Future<void>.delayed(Duration.zero);

    // When
    pending.complete(
      const Success<IssuedCredential>(
        IssuedCredential(id: 'c3', secret: 'hds_secret'),
      ),
    );
    final result = await issuing;

    // Then
    expect(result!.valueOrNull!.secret, 'hds_secret');
  });

  test('GivenARevokeInFlight_WhenTheProviderIsDisposedBeforeItCompletes_ThenNothingThrows', () async {
    // Given
    answerListWith(
      const Success<List<ApplicationCredential>>(<ApplicationCredential>[]),
    );
    final pending = Completer<Result<void>>();
    when(() => repository.revoke('s1', 'a1', 'c1'))
        .thenAnswer((_) => pending.future);
    final controller = controllerUnderTest();
    final revoking = controller.revoke(_live('c1'));
    subscription!.close();
    await Future<void>.delayed(Duration.zero);

    // When
    pending.complete(const Success<void>(null));

    // Then
    await expectLater(revoking, completes);
  });

  group('overlapping calls', () {
    late Completer<Result<IssuedCredential>> pendingIssue;
    late ApplicationCredentialsController controller;
    late Future<Result<IssuedCredential>?> firstIssue;

    setUp(() async {
      answerListWith(
        const Success<List<ApplicationCredential>>(<ApplicationCredential>[]),
      );
      pendingIssue = Completer<Result<IssuedCredential>>();
      when(
        () => repository.issue('s1', 'a1', expiresAt: any(named: 'expiresAt')),
      ).thenAnswer((_) => pendingIssue.future);
      when(() => repository.revoke('s1', 'a1', 'c1'))
          .thenAnswer((_) async => const Success<void>(null));
      controller = controllerUnderTest();
      await controller.load();
      firstIssue = controller.issue();
    });

    test(
      'GivenAnIssueInFlight_WhenIssuingAgain_ThenNoSecondCallIsMade',
      () async {
        // When
        final second = await controller.issue();

        // Then
        expect(second, isNull);
        verify(
          () =>
              repository.issue('s1', 'a1', expiresAt: any(named: 'expiresAt')),
        ).called(1);
        pendingIssue.complete(
          const Success<IssuedCredential>(
            IssuedCredential(id: 'c3', secret: 'hds_secret'),
          ),
        );
        await firstIssue;
      },
    );

    test('GivenAnIssueInFlight_WhenRevoking_ThenNoCallIsMade', () async {
      // When
      await controller.revoke(_live('c1'));

      // Then
      verifyNever(() => repository.revoke(any(), any(), any()));
      pendingIssue.complete(
        const Success<IssuedCredential>(
          IssuedCredential(id: 'c3', secret: 'hds_secret'),
        ),
      );
      await firstIssue;
    });

    test(
      'GivenAnIssueInFlight_WhenItEnds_ThenBusyHoldsUntilTheReloadFinishes',
      () async {
        // Given
        final reload = Completer<Result<List<ApplicationCredential>>>();
        when(() => repository.list('s1', 'a1'))
            .thenAnswer((_) => reload.future);

        // When
        expect(currentState().busy, isTrue);
        pendingIssue.complete(
          const Success<IssuedCredential>(
            IssuedCredential(id: 'c3', secret: 'hds_secret'),
          ),
        );
        await Future<void>.delayed(Duration.zero);

        // Then
        expect(currentState().busy, isTrue);
        expect(currentState().mayIssue, isFalse);
        reload.complete(
          Success<List<ApplicationCredential>>(<ApplicationCredential>[
            _live('c3'),
          ]),
        );
        await firstIssue;
        expect(currentState().busy, isFalse);
        expect(currentState().mayIssue, isTrue);
      },
    );
  });

  test(
    'GivenANotice_WhenARevokeFails_ThenTheNoticeClearsAndTheFailureShows',
    () async {
      // Given
      answerListWith(
        Success<List<ApplicationCredential>>(<ApplicationCredential>[
          _live('c1'),
          _live('c2'),
        ]),
      );
      final controller = controllerUnderTest();
      await controller.load();
      when(() => repository.revoke('s1', 'a1', 'c1'))
          .thenAnswer((_) async => const Success<void>(null));
      await controller.revoke(_live('c1'));
      expect(currentState().notice, isNotNull);
      when(() => repository.revoke('s1', 'a1', 'c2')).thenAnswer(
        (_) async => const FailureResult<void>(
          Failure(kind: FailureKind.forbidden, errors: <String>['Nope.']),
        ),
      );

      // When
      await controller.revoke(_live('c2'));

      // Then
      expect(currentState().notice, isNull);
      expect(currentState().actionFailure!.errors.single, 'Nope.');
    },
  );

  test(
    'GivenAnUnexpectedExceptionOnIssue_WhenIssuing_ThenItIsAFailureAndNotBusy',
    () async {
      // Given
      answerListWith(
        const Success<List<ApplicationCredential>>(<ApplicationCredential>[]),
      );
      final controller = controllerUnderTest();
      await controller.load();
      when(
        () => repository.issue('s1', 'a1', expiresAt: any(named: 'expiresAt')),
      ).thenThrow(const FormatException('bad body'));

      // When
      final result = await controller.issue();

      // Then
      expect(result, isA<FailureResult<IssuedCredential>>());
      expect(currentState().busy, isFalse);
      expect(currentState().actionFailure, isNotNull);
      expect(currentState().mayIssue, isTrue);
    },
  );

  test('GivenAnUnexpectedExceptionOnRevoke_WhenRevoking_ThenItIsAFailureAndNotBusy', () async {
    // Given
    answerListWith(
      Success<List<ApplicationCredential>>(<ApplicationCredential>[
        _live('c1'),
      ]),
    );
    final controller = controllerUnderTest();
    await controller.load();
    when(() => repository.revoke('s1', 'a1', 'c1'))
        .thenThrow(const FormatException('bad body'));

    // When
    await controller.revoke(_live('c1'));

    // Then
    expect(currentState().busy, isFalse);
    expect(currentState().actionFailure, isNotNull);
  });

  test(
    'GivenAFailedReload_WhenTheListIsStale_ThenIssuingIsNotOffered',
    () async {
      // Given
      answerListWith(
        Success<List<ApplicationCredential>>(<ApplicationCredential>[
          _live('c1'),
        ]),
      );
      final controller = controllerUnderTest();
      await controller.load();
      expect(currentState().mayIssue, isTrue);
      answerListWith(
        const FailureResult<List<ApplicationCredential>>(
          Failure(kind: FailureKind.network, errors: <String>[]),
        ),
      );

      // When
      await controller.load();

      // Then
      expect(currentState().credentials, isNotNull);
      expect(currentState().mayIssue, isFalse);
    },
  );
}
