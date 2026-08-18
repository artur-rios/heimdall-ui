import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/core/result/result.dart';
import 'package:heimdall_ui/features/permissions/domain/scope_permission.dart';
import 'package:heimdall_ui/features/permissions/domain/scope_permission_repository.dart';
import 'package:heimdall_ui/features/permissions/presentation/permission_detail_controller.dart';
import 'package:mocktail/mocktail.dart';

class _MockScopePermissionRepository extends Mock
    implements ScopePermissionRepository {}

const _readInvoices = ScopePermission(
  id: 'permission-1',
  name: 'read:invoices',
  description: 'May read invoices',
  scopeId: 'scope-1',
);

const _deleted = ScopePermission(
  id: 'permission-1',
  name: 'read:invoices',
  description: 'May read invoices',
  scopeId: 'scope-1',
  isDeleted: true,
);

const _ref = PermissionRef(scopeId: 'scope-1', permissionId: 'permission-1');

void main() {
  late _MockScopePermissionRepository repository;
  late ProviderContainer container;

  PermissionDetailController controllerUnderTest() {
    container = ProviderContainer(
      overrides: <Override>[
        scopePermissionRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    return container.read(permissionDetailControllerProvider(_ref).notifier);
  }

  PermissionDetailState currentState() =>
      container.read(permissionDetailControllerProvider(_ref));

  void answerGetWith(Result<ScopePermission> result) {
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

  void answerUpdateWith(Result<ScopePermission> result) {
    when(
      () => repository.update(
        scopeId: any(named: 'scopeId'),
        id: any(named: 'id'),
        name: any(named: 'name'),
        description: any(named: 'description'),
        includeAsJwtClaim: any(named: 'includeAsJwtClaim'),
      ),
    ).thenAnswer((_) async => result);
  }

  setUp(() {
    repository = _MockScopePermissionRepository();
  });

  test('GivenAPermission_WhenLoaded_ThenTheRecordIsShown', () async {
    // Given
    answerGetWith(const Success<ScopePermission>(_readInvoices));
    final controller = controllerUnderTest();

    // When
    await controller.load();

    // Then
    expect(
      (currentState() as PermissionDetailLoaded).permission.name,
      'read:invoices',
    );
  });

  // AF-26a — no such permission.
  test('GivenAMissingPermission_WhenLoaded_ThenStateIsNotFound', () async {
    // Given
    answerGetWith(
      const FailureResult<ScopePermission>(
        Failure(kind: FailureKind.notFound, errors: <String>[]),
      ),
    );
    final controller = controllerUnderTest();

    // When
    await controller.load();

    // Then
    expect((currentState() as PermissionDetailUnavailable).isNotFound, isTrue);
  });

  // AF-26b — out of this role's reach.
  test('GivenAForbiddenPermission_WhenLoaded_ThenStateIsForbidden', () async {
    // Given
    answerGetWith(
      const FailureResult<ScopePermission>(
        Failure(kind: FailureKind.forbidden, errors: <String>[]),
      ),
    );
    final controller = controllerUnderTest();

    // When
    await controller.load();

    // Then
    expect((currentState() as PermissionDetailUnavailable).isForbidden, isTrue);
  });

  test('GivenAnEdit_WhenSaved_ThenTheNewValuesAreSent', () async {
    // Given
    answerGetWith(const Success<ScopePermission>(_readInvoices));
    answerUpdateWith(
      const Success<ScopePermission>(
        ScopePermission(
          id: 'permission-1',
          name: 'read:all-invoices',
          description: 'May read invoices',
        ),
      ),
    );
    final controller = controllerUnderTest();
    await controller.load();

    // When
    await controller.save(
      name: 'read:all-invoices',
      description: 'May read invoices',
      includeAsJwtClaim: false,
    );

    // Then
    verify(
      () => repository.update(
        scopeId: 'scope-1',
        id: 'permission-1',
        name: 'read:all-invoices',
        description: 'May read invoices',
        includeAsJwtClaim: false,
      ),
    ).called(1);
  });

  // AF-26e — the claim flag moved, which the confirmation has to explain.
  test('GivenAChangedClaimFlag_WhenSaved_ThenTheChangeIsFlagged', () async {
    // Given
    answerGetWith(const Success<ScopePermission>(_readInvoices));
    answerUpdateWith(
      const Success<ScopePermission>(
        ScopePermission(
          id: 'permission-1',
          name: 'read:invoices',
          description: 'May read invoices',
          includeAsJwtClaim: true,
        ),
      ),
    );
    final controller = controllerUnderTest();
    await controller.load();

    // When
    await controller.save(
      name: 'read:invoices',
      description: 'May read invoices',
      includeAsJwtClaim: true,
    );

    // Then
    expect((currentState() as PermissionDetailLoaded).claimChanged, isTrue);
  });

  test('GivenAnUnchangedClaimFlag_WhenSaved_ThenNoChangeIsFlagged', () async {
    // Given
    answerGetWith(const Success<ScopePermission>(_readInvoices));
    answerUpdateWith(
      const Success<ScopePermission>(
        ScopePermission(
          id: 'permission-1',
          name: 'read:all-invoices',
          description: 'May read invoices',
        ),
      ),
    );
    final controller = controllerUnderTest();
    await controller.load();

    // When
    await controller.save(
      name: 'read:all-invoices',
      description: 'May read invoices',
      includeAsJwtClaim: false,
    );

    // Then
    expect((currentState() as PermissionDetailLoaded).claimChanged, isFalse);
  });

  // AF-26c — a refusal keeps the record and carries the API's own errors.
  test('GivenARejectedUpdate_WhenSaved_ThenApiErrorsAreKept', () async {
    // Given
    answerGetWith(const Success<ScopePermission>(_readInvoices));
    answerUpdateWith(
      const FailureResult<ScopePermission>(
        Failure(
          kind: FailureKind.validation,
          errors: <String>['A permission with that name already exists.'],
        ),
      ),
    );
    final controller = controllerUnderTest();
    await controller.load();

    // When
    await controller.save(
      name: 'read:all',
      description: 'May read invoices',
      includeAsJwtClaim: false,
    );

    // Then
    final state = currentState() as PermissionDetailLoaded;
    expect(state.saveFailure?.errors, <String>[
      'A permission with that name already exists.',
    ]);
    expect(state.permission.name, 'read:invoices');
  });

  // AF-26d — a deleted permission is read-only.
  test('GivenADeletedPermission_WhenLoaded_ThenItIsReadOnly', () async {
    // Given
    answerGetWith(const Success<ScopePermission>(_deleted));
    final controller = controllerUnderTest();

    // When
    await controller.load();

    // Then
    expect((currentState() as PermissionDetailLoaded).isReadOnly, isTrue);
  });

  test('GivenADeletedPermission_WhenSaved_ThenNoRequestIsMade', () async {
    // Given
    answerGetWith(const Success<ScopePermission>(_deleted));
    answerUpdateWith(const Success<ScopePermission>(_deleted));
    final controller = controllerUnderTest();
    await controller.load();

    // When
    await controller.save(
      name: 'anything',
      description: 'anything',
      includeAsJwtClaim: true,
    );

    // Then
    verifyNever(
      () => repository.update(
        scopeId: any(named: 'scopeId'),
        id: any(named: 'id'),
        name: any(named: 'name'),
        description: any(named: 'description'),
        includeAsJwtClaim: any(named: 'includeAsJwtClaim'),
      ),
    );
  });

  test('GivenNoChange_WhenSaved_ThenNoRequestIsMade', () async {
    // Given
    answerGetWith(const Success<ScopePermission>(_readInvoices));
    answerUpdateWith(const Success<ScopePermission>(_readInvoices));
    final controller = controllerUnderTest();
    await controller.load();

    // When
    await controller.save(
      name: 'read:invoices',
      description: 'May read invoices',
      includeAsJwtClaim: false,
    );

    // Then
    verifyNever(
      () => repository.update(
        scopeId: any(named: 'scopeId'),
        id: any(named: 'id'),
        name: any(named: 'name'),
        description: any(named: 'description'),
        includeAsJwtClaim: any(named: 'includeAsJwtClaim'),
      ),
    );
  });

  test('GivenASavedPermission_WhenAcknowledged_ThenTheNoticeClears', () async {
    // Given
    answerGetWith(const Success<ScopePermission>(_readInvoices));
    answerUpdateWith(
      const Success<ScopePermission>(
        ScopePermission(
          id: 'permission-1',
          name: 'read:invoices',
          description: 'May read invoices',
          includeAsJwtClaim: true,
        ),
      ),
    );
    final controller = controllerUnderTest();
    await controller.load();
    await controller.save(
      name: 'read:invoices',
      description: 'May read invoices',
      includeAsJwtClaim: true,
    );

    // When
    controller.acknowledgeSave();

    // Then
    final state = currentState() as PermissionDetailLoaded;
    expect(state.saved, isFalse);
    expect(state.claimChanged, isFalse);
  });

  test('GivenAnOpenPermission_WhenDeleted_ThenItIsDeleted', () async {
    // Given
    answerGetWith(const Success<ScopePermission>(_readInvoices));
    answerDeleteWith(const Success<void>(null));
    final controller = controllerUnderTest();
    await controller.load();

    // When
    await controller.delete();

    // Then
    verify(
      () => repository.delete(scopeId: 'scope-1', id: 'permission-1'),
    ).called(1);
    expect(currentState(), isA<PermissionDeleted>());
  });

  test('GivenAnOpenPermission_WhenErased_ThenTheHardEndpointIsUsed', () async {
    // Given
    answerGetWith(const Success<ScopePermission>(_readInvoices));
    answerHardDeleteWith(const Success<void>(null));
    final controller = controllerUnderTest();
    await controller.load();

    // When
    await controller.deletePermanently();

    // Then
    verify(
      () => repository.hardDelete(scopeId: 'scope-1', id: 'permission-1'),
    ).called(1);
  });

  // AF-27b — the API refused, and the permission stays open.
  test('GivenARefusedDeletion_WhenDeleted_ThenItStaysOpen', () async {
    // Given
    answerGetWith(const Success<ScopePermission>(_readInvoices));
    answerDeleteWith(
      const FailureResult<void>(
        Failure(
          kind: FailureKind.validation,
          errors: <String>['That permission is still granted to somebody.'],
        ),
      ),
    );
    final controller = controllerUnderTest();
    await controller.load();

    // When
    await controller.delete();

    // Then
    final state = currentState() as PermissionDetailLoaded;
    expect(state.deleteFailure?.errors, <String>[
      'That permission is still granted to somebody.',
    ]);
  });

  test(
    'GivenAnAlreadyDeletedPermission_WhenDeleted_ThenItCountsAsDone',
    () async {
      // Given
      answerGetWith(const Success<ScopePermission>(_readInvoices));
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
      expect(currentState(), isA<PermissionDeleted>());
    },
  );

  test('GivenADeletionInFlight_WhenAskedAgain_ThenOnlyOneIsSent', () async {
    // Given
    answerGetWith(const Success<ScopePermission>(_readInvoices));
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
    verify(
      () => repository.delete(scopeId: 'scope-1', id: 'permission-1'),
    ).called(1);
  });
}
