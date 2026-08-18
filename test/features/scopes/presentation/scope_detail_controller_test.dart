import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/core/result/result.dart';
import 'package:heimdall_ui/features/scopes/domain/scope.dart';
import 'package:heimdall_ui/features/scopes/domain/scope_repository.dart';
import 'package:heimdall_ui/features/scopes/presentation/scope_detail_controller.dart';
import 'package:heimdall_ui/features/scopes/presentation/scope_list_controller.dart';
import 'package:mocktail/mocktail.dart';

class _MockScopeRepository extends Mock implements ScopeRepository {}

const _acme = Scope(
  id: 'scope-1',
  name: 'Acme',
  description: 'The first tenant',
  ownerIds: <String>['person-1'],
);

const _deleted = Scope(
  id: 'scope-1',
  name: 'Acme',
  description: 'The first tenant',
  isDeleted: true,
);

void main() {
  late _MockScopeRepository repository;
  late ProviderContainer container;

  ScopeDetailController controllerUnderTest() {
    container = ProviderContainer(
      overrides: <Override>[
        scopeRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    return container.read(scopeDetailControllerProvider('scope-1').notifier);
  }

  ScopeDetailState currentState() =>
      container.read(scopeDetailControllerProvider('scope-1'));

  void answerGetWith(Result<Scope> result) {
    when(
      () => repository.getById(
        any(),
        includeDeleted: any(named: 'includeDeleted'),
      ),
    ).thenAnswer((_) async => result);
  }

  void answerDeleteWith(Result<void> result) {
    when(() => repository.delete(any())).thenAnswer((_) async => result);
  }

  void answerHardDeleteWith(Result<void> result) {
    when(() => repository.hardDelete(any())).thenAnswer((_) async => result);
  }

  void answerToggleWith(Result<Scope> result) {
    when(
      () => repository.setGoogleSignIn(
        id: any(named: 'id'),
        enabled: any(named: 'enabled'),
      ),
    ).thenAnswer((_) async => result);
  }

  void answerUpdateWith(Result<Scope> result) {
    when(
      () => repository.update(
        id: any(named: 'id'),
        name: any(named: 'name'),
        description: any(named: 'description'),
      ),
    ).thenAnswer((_) async => result);
  }

  setUp(() {
    repository = _MockScopeRepository();
  });

  test('GivenAScope_WhenLoaded_ThenTheRecordIsShown', () async {
    // Given
    answerGetWith(const Success<Scope>(_acme));
    final controller = controllerUnderTest();

    // When
    await controller.load();

    // Then
    expect((currentState() as ScopeDetailLoaded).scope.name, 'Acme');
  });

  test('GivenAScope_WhenLoaded_ThenTheIdentifierIsRead', () async {
    // Given
    answerGetWith(const Success<Scope>(_acme));
    final controller = controllerUnderTest();

    // When
    await controller.load();

    // Then
    verify(() => repository.getById('scope-1')).called(1);
  });

  // AF-12a — no such scope.
  test('GivenAMissingScope_WhenLoaded_ThenStateIsNotFound', () async {
    // Given
    answerGetWith(
      const FailureResult<Scope>(
        Failure(kind: FailureKind.notFound, errors: <String>[]),
      ),
    );
    final controller = controllerUnderTest();

    // When
    await controller.load();

    // Then
    expect((currentState() as ScopeDetailUnavailable).isNotFound, isTrue);
  });

  // AF-12b — the scope is not this caller's.
  test('GivenAForbiddenScope_WhenLoaded_ThenStateIsForbidden', () async {
    // Given
    answerGetWith(
      const FailureResult<Scope>(
        Failure(kind: FailureKind.forbidden, errors: <String>[]),
      ),
    );
    final controller = controllerUnderTest();

    // When
    await controller.load();

    // Then
    expect((currentState() as ScopeDetailUnavailable).isForbidden, isTrue);
  });

  test('GivenAChangedName_WhenSaved_ThenTheNewValuesAreSent', () async {
    // Given
    answerGetWith(const Success<Scope>(_acme));
    answerUpdateWith(
      const Success<Scope>(
        Scope(id: 'scope-1', name: 'Acme Ltd', description: 'The first tenant'),
      ),
    );
    final controller = controllerUnderTest();
    await controller.load();

    // When
    await controller.save(name: 'Acme Ltd', description: 'The first tenant');

    // Then
    verify(
      () => repository.update(
        id: 'scope-1',
        name: 'Acme Ltd',
        description: 'The first tenant',
      ),
    ).called(1);
  });

  // AF-12c — a refusal keeps the record and carries the API's own errors.
  test('GivenARejectedUpdate_WhenSaved_ThenApiErrorsAreKept', () async {
    // Given
    answerGetWith(const Success<Scope>(_acme));
    answerUpdateWith(
      const FailureResult<Scope>(
        Failure(
          kind: FailureKind.validation,
          errors: <String>['A scope with that name already exists.'],
        ),
      ),
    );
    final controller = controllerUnderTest();
    await controller.load();

    // When
    await controller.save(name: 'Globex', description: 'The first tenant');

    // Then
    final state = currentState() as ScopeDetailLoaded;
    expect(state.saveFailure?.errors, <String>[
      'A scope with that name already exists.',
    ]);
    expect(state.scope.name, 'Acme');
  });

  // AF-12d — a deleted scope is read-only.
  test('GivenADeletedScope_WhenLoaded_ThenItIsReadOnly', () async {
    // Given
    answerGetWith(const Success<Scope>(_deleted));
    final controller = controllerUnderTest();

    // When
    await controller.load();

    // Then
    expect((currentState() as ScopeDetailLoaded).isReadOnly, isTrue);
  });

  test('GivenADeletedScope_WhenSaved_ThenNoRequestIsMade', () async {
    // Given
    answerGetWith(const Success<Scope>(_deleted));
    answerUpdateWith(const Success<Scope>(_deleted));
    final controller = controllerUnderTest();
    await controller.load();

    // When
    await controller.save(name: 'Anything', description: 'Anything');

    // Then
    verifyNever(
      () => repository.update(
        id: any(named: 'id'),
        name: any(named: 'name'),
        description: any(named: 'description'),
      ),
    );
  });

  // AF-12e — saving with nothing changed is a no-op.
  test('GivenNoChange_WhenSaved_ThenNoRequestIsMade', () async {
    // Given
    answerGetWith(const Success<Scope>(_acme));
    answerUpdateWith(const Success<Scope>(_acme));
    final controller = controllerUnderTest();
    await controller.load();

    // When
    await controller.save(name: 'Acme', description: 'The first tenant');

    // Then
    verifyNever(
      () => repository.update(
        id: any(named: 'id'),
        name: any(named: 'name'),
        description: any(named: 'description'),
      ),
    );
  });

  test('GivenASavedScope_WhenAcknowledged_ThenTheNoticeClears', () async {
    // Given
    answerGetWith(const Success<Scope>(_acme));
    answerUpdateWith(
      const Success<Scope>(
        Scope(id: 'scope-1', name: 'Acme Ltd', description: 'The first tenant'),
      ),
    );
    final controller = controllerUnderTest();
    await controller.load();
    await controller.save(name: 'Acme Ltd', description: 'The first tenant');

    // When
    controller.acknowledgeSave();

    // Then
    expect((currentState() as ScopeDetailLoaded).saved, isFalse);
  });

  test('GivenATransportFailure_WhenLoaded_ThenStateIsUnavailable', () async {
    // Given
    answerGetWith(
      const FailureResult<Scope>(
        Failure(kind: FailureKind.network, errors: <String>[]),
      ),
    );
    final controller = controllerUnderTest();

    // When
    await controller.load();

    // Then
    final state = currentState() as ScopeDetailUnavailable;
    expect(state.isNotFound, isFalse);
    expect(state.isForbidden, isFalse);
  });

  test('GivenAnOpenScope_WhenDeleted_ThenTheScopeIsDeleted', () async {
    // Given
    answerGetWith(const Success<Scope>(_acme));
    answerDeleteWith(const Success<void>(null));
    final controller = controllerUnderTest();
    await controller.load();

    // When
    await controller.delete();

    // Then
    verify(() => repository.delete('scope-1')).called(1);
    expect(currentState(), isA<ScopeDeleted>());
  });

  test(
    'GivenAnOpenScope_WhenDeletedPermanently_ThenTheHardEndpointIsUsed',
    () async {
      // Given
      answerGetWith(const Success<Scope>(_acme));
      answerHardDeleteWith(const Success<void>(null));
      final controller = controllerUnderTest();
      await controller.load();

      // When
      await controller.deletePermanently();

      // Then
      verify(() => repository.hardDelete('scope-1')).called(1);
    },
  );

  // AF-13b — the API refused, and the scope stays open.
  test('GivenARefusedDeletion_WhenDeleted_ThenTheScopeStaysOpen', () async {
    // Given
    answerGetWith(const Success<Scope>(_acme));
    answerDeleteWith(
      const FailureResult<void>(
        Failure(
          kind: FailureKind.validation,
          errors: <String>['The scope still holds users.'],
        ),
      ),
    );
    final controller = controllerUnderTest();
    await controller.load();

    // When
    await controller.delete();

    // Then
    final state = currentState() as ScopeDetailLoaded;
    expect(state.deleteFailure?.errors, <String>[
      'The scope still holds users.',
    ]);
  });

  // AF-13d — already deleted is the outcome that was asked for.
  test('GivenAnAlreadyDeletedScope_WhenDeleted_ThenItCountsAsDone', () async {
    // Given
    answerGetWith(const Success<Scope>(_acme));
    answerDeleteWith(
      const FailureResult<void>(
        Failure(kind: FailureKind.notFound, errors: <String>[]),
      ),
    );
    final controller = controllerUnderTest();
    await controller.load();

    // When
    await controller.delete();

    // Then
    expect(currentState(), isA<ScopeDeleted>());
  });

  test('GivenADeletionInFlight_WhenAskedAgain_ThenOnlyOneIsSent', () async {
    // Given
    answerGetWith(const Success<Scope>(_acme));
    final pending = Completer<Result<void>>();
    when(() => repository.delete(any())).thenAnswer((_) => pending.future);
    final controller = controllerUnderTest();
    await controller.load();

    // When
    final first = controller.delete();
    final second = controller.delete();
    pending.complete(const Success<void>(null));
    await Future.wait<void>(<Future<void>>[first, second]);

    // Then
    verify(() => repository.delete('scope-1')).called(1);
  });

  test('GivenGoogleSignInOff_WhenTurnedOn_ThenTheApiIsAsked', () async {
    // Given
    answerGetWith(const Success<Scope>(_acme));
    answerToggleWith(
      const Success<Scope>(
        Scope(
          id: 'scope-1',
          name: 'Acme',
          description: 'The first tenant',
          googleSignInEnabled: true,
        ),
      ),
    );
    final controller = controllerUnderTest();
    await controller.load();

    // When
    await controller.setGoogleSignIn(true);

    // Then
    verify(
      () => repository.setGoogleSignIn(id: 'scope-1', enabled: true),
    ).called(1);
  });

  test(
    'GivenAConfirmedToggle_WhenItReturns_ThenTheControlSettlesOnIt',
    () async {
      // Given
      answerGetWith(const Success<Scope>(_acme));
      answerToggleWith(
        const Success<Scope>(
          Scope(
            id: 'scope-1',
            name: 'Acme',
            description: 'The first tenant',
            googleSignInEnabled: true,
          ),
        ),
      );
      final controller = controllerUnderTest();
      await controller.load();

      // When
      await controller.setGoogleSignIn(true);

      // Then
      final state = currentState() as ScopeDetailLoaded;
      expect(state.scope.googleSignInEnabled, isTrue);
      expect(state.togglingGoogleSignIn, isFalse);
    },
  );

  // AF-15a — the control returns to where the API still has it.
  test('GivenARefusedToggle_WhenAttempted_ThenTheStateIsUnchanged', () async {
    // Given
    answerGetWith(const Success<Scope>(_acme));
    answerToggleWith(
      const FailureResult<Scope>(
        Failure(
          kind: FailureKind.validation,
          errors: <String>['That scope is not active.'],
        ),
      ),
    );
    final controller = controllerUnderTest();
    await controller.load();

    // When
    await controller.setGoogleSignIn(true);

    // Then
    final state = currentState() as ScopeDetailLoaded;
    expect(state.scope.googleSignInEnabled, isFalse);
    expect(state.googleSignInFailure?.errors, <String>[
      'That scope is not active.',
    ]);
  });

  // AF-15c — a request in flight is not joined by a second one.
  test('GivenAToggleInFlight_WhenToggledAgain_ThenOnlyOneIsSent', () async {
    // Given
    answerGetWith(const Success<Scope>(_acme));
    final pending = Completer<Result<Scope>>();
    when(
      () => repository.setGoogleSignIn(
        id: any(named: 'id'),
        enabled: any(named: 'enabled'),
      ),
    ).thenAnswer((_) => pending.future);
    final controller = controllerUnderTest();
    await controller.load();

    // When
    final first = controller.setGoogleSignIn(true);
    final second = controller.setGoogleSignIn(false);
    pending.complete(const Success<Scope>(_acme));
    await Future.wait<void>(<Future<void>>[first, second]);

    // Then
    verify(
      () => repository.setGoogleSignIn(
        id: any(named: 'id'),
        enabled: any(named: 'enabled'),
      ),
    ).called(1);
  });

  // AF-12d — a deleted scope cannot be changed from here, and that includes
  // this control.
  test('GivenADeletedScope_WhenToggled_ThenNoRequestIsMade', () async {
    // Given
    answerGetWith(const Success<Scope>(_deleted));
    answerToggleWith(const Success<Scope>(_deleted));
    final controller = controllerUnderTest();
    await controller.load();

    // When
    await controller.setGoogleSignIn(true);

    // Then
    verifyNever(
      () => repository.setGoogleSignIn(
        id: any(named: 'id'),
        enabled: any(named: 'enabled'),
      ),
    );
  });
}
