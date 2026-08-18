import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/core/result/result.dart';
import 'package:heimdall_ui/features/applications/domain/application.dart';
import 'package:heimdall_ui/features/applications/domain/application_repository.dart';
import 'package:heimdall_ui/features/applications/presentation/application_detail_controller.dart';
import 'package:mocktail/mocktail.dart';

class _MockApplicationRepository extends Mock
    implements ApplicationRepository {}

const _billing = Application(
  id: 'app-1',
  name: 'Billing',
  ownerId: 'person-1',
  scopeId: 'scope-1',
);

const _deleted = Application(
  id: 'app-1',
  name: 'Billing',
  ownerId: 'person-1',
  scopeId: 'scope-1',
  isDeleted: true,
);

const _ref = ApplicationRef(scopeId: 'scope-1', applicationId: 'app-1');

void main() {
  late _MockApplicationRepository repository;
  late ProviderContainer container;

  ApplicationDetailController controllerUnderTest() {
    container = ProviderContainer(
      overrides: <Override>[
        applicationRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    return container.read(applicationDetailControllerProvider(_ref).notifier);
  }

  ApplicationDetailState currentState() =>
      container.read(applicationDetailControllerProvider(_ref));

  void answerGetWith(Result<Application> result) {
    when(
      () => repository.getById(
        scopeId: any(named: 'scopeId'),
        id: any(named: 'id'),
        includeDeleted: any(named: 'includeDeleted'),
      ),
    ).thenAnswer((_) async => result);
  }

  void answerDeleteWith(Result<void> result) {
    when(
      () => repository.delete(
        scopeId: any(named: 'scopeId'),
        id: any(named: 'id'),
      ),
    ).thenAnswer((_) async => result);
  }

  void answerHardDeleteWith(Result<void> result) {
    when(
      () => repository.hardDelete(
        scopeId: any(named: 'scopeId'),
        id: any(named: 'id'),
      ),
    ).thenAnswer((_) async => result);
  }

  void answerUpdateWith(Result<Application> result) {
    when(
      () => repository.update(
        scopeId: any(named: 'scopeId'),
        id: any(named: 'id'),
        name: any(named: 'name'),
        ownerId: any(named: 'ownerId'),
      ),
    ).thenAnswer((_) async => result);
  }

  setUp(() {
    repository = _MockApplicationRepository();
  });

  test('GivenAnApplication_WhenLoaded_ThenTheRecordIsShown', () async {
    // Given
    answerGetWith(const Success<Application>(_billing));
    final controller = controllerUnderTest();

    // When
    await controller.load();

    // Then
    expect(
      (currentState() as ApplicationDetailLoaded).application.name,
      'Billing',
    );
  });

  test('GivenAnApplication_WhenLoaded_ThenBothIdentifiersAreUsed', () async {
    // Given
    answerGetWith(const Success<Application>(_billing));
    final controller = controllerUnderTest();

    // When
    await controller.load();

    // Then
    verify(() => repository.getById(scopeId: 'scope-1', id: 'app-1')).called(1);
  });

  // AF-22a — no such application.
  test('GivenAMissingApplication_WhenLoaded_ThenStateIsNotFound', () async {
    // Given
    answerGetWith(
      const FailureResult<Application>(
        Failure(kind: FailureKind.notFound, errors: <String>[]),
      ),
    );
    final controller = controllerUnderTest();

    // When
    await controller.load();

    // Then
    expect((currentState() as ApplicationDetailUnavailable).isNotFound, isTrue);
  });

  // AF-22b — out of this role's reach.
  test('GivenAForbiddenApplication_WhenLoaded_ThenStateIsForbidden', () async {
    // Given
    answerGetWith(
      const FailureResult<Application>(
        Failure(kind: FailureKind.forbidden, errors: <String>[]),
      ),
    );
    final controller = controllerUnderTest();

    // When
    await controller.load();

    // Then
    expect(
      (currentState() as ApplicationDetailUnavailable).isForbidden,
      isTrue,
    );
  });

  test('GivenAnEdit_WhenSaved_ThenTheNewValuesAreSent', () async {
    // Given
    answerGetWith(const Success<Application>(_billing));
    answerUpdateWith(
      const Success<Application>(
        Application(id: 'app-1', name: 'Invoicing', ownerId: 'person-2'),
      ),
    );
    final controller = controllerUnderTest();
    await controller.load();

    // When
    await controller.save(name: 'Invoicing', ownerId: 'person-2');

    // Then
    verify(
      () => repository.update(
        scopeId: 'scope-1',
        id: 'app-1',
        name: 'Invoicing',
        ownerId: 'person-2',
      ),
    ).called(1);
  });

  // AF-22c — a refusal keeps the record and carries the API's own errors.
  test('GivenARejectedUpdate_WhenSaved_ThenApiErrorsAreKept', () async {
    // Given
    answerGetWith(const Success<Application>(_billing));
    answerUpdateWith(
      const FailureResult<Application>(
        Failure(
          kind: FailureKind.validation,
          errors: <String>['An application with that name already exists.'],
        ),
      ),
    );
    final controller = controllerUnderTest();
    await controller.load();

    // When
    await controller.save(name: 'Invoicing', ownerId: 'person-1');

    // Then
    final state = currentState() as ApplicationDetailLoaded;
    expect(state.saveFailure?.errors, <String>[
      'An application with that name already exists.',
    ]);
    expect(state.application.name, 'Billing');
  });

  // AF-22d — a deleted application is read-only.
  test('GivenADeletedApplication_WhenLoaded_ThenItIsReadOnly', () async {
    // Given
    answerGetWith(const Success<Application>(_deleted));
    final controller = controllerUnderTest();

    // When
    await controller.load();

    // Then
    expect((currentState() as ApplicationDetailLoaded).isReadOnly, isTrue);
  });

  test('GivenADeletedApplication_WhenSaved_ThenNoRequestIsMade', () async {
    // Given
    answerGetWith(const Success<Application>(_deleted));
    answerUpdateWith(const Success<Application>(_deleted));
    final controller = controllerUnderTest();
    await controller.load();

    // When
    await controller.save(name: 'Anything', ownerId: 'person-2');

    // Then
    verifyNever(
      () => repository.update(
        scopeId: any(named: 'scopeId'),
        id: any(named: 'id'),
        name: any(named: 'name'),
        ownerId: any(named: 'ownerId'),
      ),
    );
  });

  // AF-22e — saving with nothing changed is a no-op.
  test('GivenNoChange_WhenSaved_ThenNoRequestIsMade', () async {
    // Given
    answerGetWith(const Success<Application>(_billing));
    answerUpdateWith(const Success<Application>(_billing));
    final controller = controllerUnderTest();
    await controller.load();

    // When
    await controller.save(name: 'Billing', ownerId: 'person-1');

    // Then
    verifyNever(
      () => repository.update(
        scopeId: any(named: 'scopeId'),
        id: any(named: 'id'),
        name: any(named: 'name'),
        ownerId: any(named: 'ownerId'),
      ),
    );
  });

  test('GivenASavedApplication_WhenAcknowledged_ThenTheNoticeClears', () async {
    // Given
    answerGetWith(const Success<Application>(_billing));
    answerUpdateWith(
      const Success<Application>(
        Application(id: 'app-1', name: 'Invoicing', ownerId: 'person-1'),
      ),
    );
    final controller = controllerUnderTest();
    await controller.load();
    await controller.save(name: 'Invoicing', ownerId: 'person-1');

    // When
    controller.acknowledgeSave();

    // Then
    expect((currentState() as ApplicationDetailLoaded).saved, isFalse);
  });

  // Two applications in two scopes are two states, not one.
  test('GivenTwoApplications_WhenKeyed_ThenTheirStatesAreSeparate', () async {
    // Given
    answerGetWith(const Success<Application>(_billing));
    final controller = controllerUnderTest();
    await controller.load();

    // When
    final other = container.read(
      applicationDetailControllerProvider(
        const ApplicationRef(scopeId: 'scope-2', applicationId: 'app-2'),
      ),
    );

    // Then
    expect(other, isA<ApplicationDetailLoading>());
  });

  test('GivenAnOpenApplication_WhenDeleted_ThenItIsDeleted', () async {
    // Given
    answerGetWith(const Success<Application>(_billing));
    answerDeleteWith(const Success<void>(null));
    final controller = controllerUnderTest();
    await controller.load();

    // When
    await controller.delete();

    // Then
    verify(() => repository.delete(scopeId: 'scope-1', id: 'app-1')).called(1);
    expect(currentState(), isA<ApplicationDeleted>());
  });

  test('GivenAnOpenApplication_WhenErased_ThenTheHardEndpointIsUsed', () async {
    // Given
    answerGetWith(const Success<Application>(_billing));
    answerHardDeleteWith(const Success<void>(null));
    final controller = controllerUnderTest();
    await controller.load();

    // When
    await controller.deletePermanently();

    // Then
    verify(
      () => repository.hardDelete(scopeId: 'scope-1', id: 'app-1'),
    ).called(1);
  });

  // AF-23b — the API refused, and the application stays open.
  test('GivenARefusedDeletion_WhenDeleted_ThenItStaysOpen', () async {
    // Given
    answerGetWith(const Success<Application>(_billing));
    answerDeleteWith(
      const FailureResult<void>(
        Failure(
          kind: FailureKind.validation,
          errors: <String>['That application is still in use.'],
        ),
      ),
    );
    final controller = controllerUnderTest();
    await controller.load();

    // When
    await controller.delete();

    // Then
    final state = currentState() as ApplicationDetailLoaded;
    expect(state.deleteFailure?.errors, <String>[
      'That application is still in use.',
    ]);
  });

  test(
    'GivenAnAlreadyDeletedApplication_WhenDeleted_ThenItCountsAsDone',
    () async {
      // Given
      answerGetWith(const Success<Application>(_billing));
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
      expect(currentState(), isA<ApplicationDeleted>());
    },
  );

  test('GivenADeletionInFlight_WhenAskedAgain_ThenOnlyOneIsSent', () async {
    // Given
    answerGetWith(const Success<Application>(_billing));
    final pending = Completer<Result<void>>();
    when(
      () => repository.delete(
        scopeId: any(named: 'scopeId'),
        id: any(named: 'id'),
      ),
    ).thenAnswer((_) => pending.future);
    final controller = controllerUnderTest();
    await controller.load();

    // When
    final first = controller.delete();
    final second = controller.delete();
    pending.complete(const Success<void>(null));
    await Future.wait<void>(<Future<void>>[first, second]);

    // Then
    verify(() => repository.delete(scopeId: 'scope-1', id: 'app-1')).called(1);
  });
}
