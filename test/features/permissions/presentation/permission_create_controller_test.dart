import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/core/result/result.dart';
import 'package:heimdall_ui/features/permissions/domain/scope_permission.dart';
import 'package:heimdall_ui/features/permissions/domain/scope_permission_repository.dart';
import 'package:heimdall_ui/features/permissions/presentation/permission_create_controller.dart';
import 'package:mocktail/mocktail.dart';

import '../../../support/late_answer.dart';

class _MockScopePermissionRepository extends Mock
    implements ScopePermissionRepository {}

const _readInvoices = ScopePermission(
  id: 'permission-1',
  name: 'read:invoices',
  description: 'May read invoices',
  scopeId: 'scope-1',
);

void main() {
  late _MockScopePermissionRepository repository;
  late ProviderContainer container;

  PermissionCreateController controllerUnderTest() {
    container = ProviderContainer(
      overrides: <Override>[
        scopePermissionRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    return container.read(
      permissionCreateControllerProvider('scope-1').notifier,
    );
  }

  setUp(() {
    repository = _MockScopePermissionRepository();
  });

  // A sign-out resets the form while its submission is in flight, and the late
  // answer must not land in the reset state.
  test(
    'GivenACreateInFlight_WhenTheSessionResets_ThenTheAnswerIsDropped',
    () async {
      // Given
      final answer = Completer<Result<ScopePermission>>();
      when(
        () => repository.create(
          scopeId: any(named: 'scopeId'),
          name: any(named: 'name'),
          description: any(named: 'description'),
          includeAsJwtClaim: any(named: 'includeAsJwtClaim'),
        ),
      ).thenAnswer((_) => answer.future);
      final controller = controllerUnderTest();

      // When
      await answerAfterReset(
        container,
        permissionCreateControllerProvider('scope-1'),
        reset: permissionCreateControllerProvider,
        start: () => controller.create(
          name: 'read:invoices',
          description: 'May read invoices',
          includeAsJwtClaim: false,
        ),
        answer: () =>
            answer.complete(const Success<ScopePermission>(_readInvoices)),
      );

      // Then
      expect(
        container.read(permissionCreateControllerProvider('scope-1')),
        isA<PermissionCreateEditing>(),
      );
    },
  );
}
