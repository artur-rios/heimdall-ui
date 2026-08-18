import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/core/result/result.dart';
import 'package:heimdall_ui/features/scopes/domain/scope.dart';
import 'package:heimdall_ui/features/scopes/domain/scope_repository.dart';
import 'package:heimdall_ui/features/scopes/presentation/scope_create_controller.dart';
import 'package:heimdall_ui/features/scopes/presentation/scope_list_controller.dart';
import 'package:mocktail/mocktail.dart';

class _MockScopeRepository extends Mock implements ScopeRepository {}

const _created = Scope(
  id: 'scope-9',
  name: 'Acme',
  description: 'The first tenant',
  ownerIds: <String>['person-1'],
);

void main() {
  late _MockScopeRepository repository;
  late ProviderContainer container;

  ScopeCreateController controllerUnderTest() {
    container = ProviderContainer(
      overrides: <Override>[
        scopeRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    return container.read(scopeCreateControllerProvider.notifier);
  }

  void answerWith(Result<Scope> result) {
    when(
      () => repository.create(
        name: any(named: 'name'),
        description: any(named: 'description'),
        ownerIds: any(named: 'ownerIds'),
      ),
    ).thenAnswer((_) async => result);
  }

  setUp(() {
    repository = _MockScopeRepository();
  });

  test('GivenAValidForm_WhenCreated_ThenTheScopeIsReturned', () async {
    // Given
    answerWith(const Success<Scope>(_created));
    final controller = controllerUnderTest();

    // When
    await controller.create(
      name: 'Acme',
      description: 'The first tenant',
      ownerIds: const <String>['person-1'],
    );

    // Then
    final state = container.read(scopeCreateControllerProvider);
    expect((state as ScopeCreated).scope.id, 'scope-9');
  });

  test('GivenAValidForm_WhenCreated_ThenTheValuesAreSent', () async {
    // Given
    answerWith(const Success<Scope>(_created));
    final controller = controllerUnderTest();

    // When
    await controller.create(
      name: 'Acme',
      description: 'The first tenant',
      ownerIds: const <String>['person-1', 'person-2'],
    );

    // Then
    verify(
      () => repository.create(
        name: 'Acme',
        description: 'The first tenant',
        ownerIds: <String>['person-1', 'person-2'],
      ),
    ).called(1);
  });

  // AF-11b — a duplicate name, reported in the API's own words.
  test('GivenADuplicateName_WhenCreated_ThenApiErrorsAreKept', () async {
    // Given
    answerWith(
      const FailureResult<Scope>(
        Failure(
          kind: FailureKind.validation,
          errors: <String>['A scope with that name already exists.'],
        ),
      ),
    );
    final controller = controllerUnderTest();

    // When
    await controller.create(
      name: 'Acme',
      description: '',
      ownerIds: const <String>['person-1'],
    );

    // Then
    final state = container.read(scopeCreateControllerProvider);
    expect((state as ScopeCreateRejected).failure.errors, <String>[
      'A scope with that name already exists.',
    ]);
  });

  // AF-11c — an owner the API will not accept.
  test('GivenARejectedOwner_WhenCreated_ThenApiErrorsAreKept', () async {
    // Given
    answerWith(
      const FailureResult<Scope>(
        Failure(
          kind: FailureKind.validation,
          errors: <String>['person-9 is not a Scope Admin.'],
        ),
      ),
    );
    final controller = controllerUnderTest();

    // When
    await controller.create(
      name: 'Acme',
      description: '',
      ownerIds: const <String>['person-9'],
    );

    // Then
    final state = container.read(scopeCreateControllerProvider);
    expect((state as ScopeCreateRejected).failure.errors, <String>[
      'person-9 is not a Scope Admin.',
    ]);
  });

  // AF-11e — nothing reached the API.
  test('GivenATransportFailure_WhenCreated_ThenStateIsRejected', () async {
    // Given
    answerWith(
      const FailureResult<Scope>(
        Failure(kind: FailureKind.network, errors: <String>[]),
      ),
    );
    final controller = controllerUnderTest();

    // When
    await controller.create(
      name: 'Acme',
      description: '',
      ownerIds: const <String>['person-1'],
    );

    // Then
    final state = container.read(scopeCreateControllerProvider);
    expect((state as ScopeCreateRejected).failure.kind, FailureKind.network);
  });

  test(
    'GivenARejectedAttempt_WhenReturnedToEditing_ThenStateIsEditing',
    () async {
      // Given
      answerWith(
        const FailureResult<Scope>(
          Failure(kind: FailureKind.network, errors: <String>[]),
        ),
      );
      final controller = controllerUnderTest();
      await controller.create(
        name: 'Acme',
        description: '',
        ownerIds: const <String>['person-1'],
      );

      // When
      controller.backToEditing();

      // Then
      expect(
        container.read(scopeCreateControllerProvider),
        isA<ScopeCreateEditing>(),
      );
    },
  );

  test('GivenARequestInFlight_WhenSubmittedAgain_ThenOnlyOneIsSent', () async {
    // Given
    final pending = Completer<Result<Scope>>();
    when(
      () => repository.create(
        name: any(named: 'name'),
        description: any(named: 'description'),
        ownerIds: any(named: 'ownerIds'),
      ),
    ).thenAnswer((_) => pending.future);
    final controller = controllerUnderTest();

    // When
    final first = controller.create(
      name: 'Acme',
      description: '',
      ownerIds: const <String>['person-1'],
    );
    final second = controller.create(
      name: 'Acme',
      description: '',
      ownerIds: const <String>['person-1'],
    );
    pending.complete(const Success<Scope>(_created));
    await Future.wait<void>(<Future<void>>[first, second]);

    // Then
    verify(
      () => repository.create(
        name: any(named: 'name'),
        description: any(named: 'description'),
        ownerIds: any(named: 'ownerIds'),
      ),
    ).called(1);
  });
}
