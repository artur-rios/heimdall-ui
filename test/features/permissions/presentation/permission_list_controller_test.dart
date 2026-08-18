import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/core/network/envelope.dart';
import 'package:heimdall_ui/core/result/result.dart';
import 'package:heimdall_ui/features/permissions/domain/scope_permission.dart';
import 'package:heimdall_ui/features/permissions/domain/scope_permission_repository.dart';
import 'package:heimdall_ui/features/permissions/presentation/permission_list_controller.dart';
import 'package:mocktail/mocktail.dart';

class _MockScopePermissionRepository extends Mock
    implements ScopePermissionRepository {}

const _readInvoices = ScopePermission(
  id: 'permission-1',
  name: 'read:invoices',
  description: 'May read invoices',
  includeAsJwtClaim: true,
);

Page<ScopePermission> _page({
  List<ScopePermission> items = const <ScopePermission>[_readInvoices],
  int pageNumber = 1,
  int totalPages = 1,
}) => Page<ScopePermission>(
  items: items,
  pageNumber: pageNumber,
  pageSize: 20,
  totalItems: items.length,
  totalPages: totalPages,
);

void main() {
  late _MockScopePermissionRepository repository;
  late ProviderContainer container;

  PermissionListController controllerUnderTest() {
    container = ProviderContainer(
      overrides: <Override>[
        scopePermissionRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    return container.read(permissionListControllerProvider('scope-1').notifier);
  }

  PermissionListState currentState() =>
      container.read(permissionListControllerProvider('scope-1'));

  void answerWith(Result<Page<ScopePermission>> result) {
    when(
      () => repository.list(
        scopeId: any(named: 'scopeId'),
        name: any(named: 'name'),
        includeDeleted: any(named: 'includeDeleted'),
        pageNumber: any(named: 'pageNumber'),
        pageSize: any(named: 'pageSize'),
      ),
    ).thenAnswer((_) async => result);
  }

  setUp(() {
    repository = _MockScopePermissionRepository();
  });

  test('GivenAPage_WhenLoaded_ThenThePermissionsAreShown', () async {
    // Given
    answerWith(Success<Page<ScopePermission>>(_page()));
    final controller = controllerUnderTest();

    // When
    await controller.load();

    // Then
    expect(
      (currentState() as PermissionListLoaded).page.items.single.name,
      'read:invoices',
    );
  });

  test('GivenAScope_WhenLoaded_ThenThatScopeIsRead', () async {
    // Given
    answerWith(Success<Page<ScopePermission>>(_page()));
    final controller = controllerUnderTest();

    // When
    await controller.load();

    // Then
    verify(
      () => repository.list(
        scopeId: 'scope-1',
        name: '',
        includeDeleted: false,
        pageNumber: 1,
      ),
    ).called(1);
  });

  test('GivenASearch_WhenSubmitted_ThenTheNameIsSent', () async {
    // Given
    answerWith(Success<Page<ScopePermission>>(_page()));
    final controller = controllerUnderTest();

    // When
    await controller.search('read');

    // Then
    verify(
      () => repository.list(
        scopeId: 'scope-1',
        name: 'read',
        includeDeleted: false,
        pageNumber: 1,
      ),
    ).called(1);
  });

  test('GivenAPageOtherThanTheFirst_WhenSearched_ThenPagingResets', () async {
    // Given
    answerWith(Success<Page<ScopePermission>>(_page(totalPages: 5)));
    final controller = controllerUnderTest();
    await controller.load();
    await controller.goToPage(3);

    // When
    await controller.search('read');

    // Then
    expect(currentState().query.pageNumber, 1);
  });

  test('GivenIncludeDeleted_WhenToggled_ThenTheFlagIsSent', () async {
    // Given
    answerWith(Success<Page<ScopePermission>>(_page()));
    final controller = controllerUnderTest();

    // When
    await controller.setIncludeDeleted(true);

    // Then
    verify(
      () => repository.list(
        scopeId: 'scope-1',
        name: '',
        includeDeleted: true,
        pageNumber: 1,
      ),
    ).called(1);
  });

  test('GivenAPageChange_WhenRequested_ThenThatPageIsRead', () async {
    // Given
    answerWith(Success<Page<ScopePermission>>(_page(totalPages: 4)));
    final controller = controllerUnderTest();
    await controller.load();

    // When
    await controller.goToPage(2);

    // Then
    verify(
      () => repository.list(
        scopeId: 'scope-1',
        name: '',
        includeDeleted: false,
        pageNumber: 2,
      ),
    ).called(1);
  });

  // AF-24b — the query that failed is kept, so the retry asks it again.
  test('GivenAFailedRequest_WhenSearched_ThenTheFiltersSurvive', () async {
    // Given
    answerWith(
      const FailureResult<Page<ScopePermission>>(
        Failure(kind: FailureKind.network, errors: <String>[]),
      ),
    );
    final controller = controllerUnderTest();

    // When
    await controller.search('read');

    // Then
    expect(currentState().query.name, 'read');
  });

  test('GivenARefusedListing_WhenLoaded_ThenApiErrorsAreKept', () async {
    // Given
    answerWith(
      const FailureResult<Page<ScopePermission>>(
        Failure(
          kind: FailureKind.validation,
          errors: <String>['Page size is too large.'],
        ),
      ),
    );
    final controller = controllerUnderTest();

    // When
    await controller.load();

    // Then
    expect((currentState() as PermissionListFailed).failure.errors, <String>[
      'Page size is too large.',
    ]);
  });

  // AF-24c — a scope this admin does not own.
  test('GivenAForbiddenScope_WhenLoaded_ThenStateIsForbidden', () async {
    // Given
    answerWith(
      const FailureResult<Page<ScopePermission>>(
        Failure(kind: FailureKind.forbidden, errors: <String>[]),
      ),
    );
    final controller = controllerUnderTest();

    // When
    await controller.load();

    // Then
    expect((currentState() as PermissionListFailed).isForbidden, isTrue);
  });

  // AF-24a — a filtered listing knows it is filtered.
  test('GivenASearch_WhenApplied_ThenTheQueryIsFiltered', () async {
    // Given
    answerWith(
      Success<Page<ScopePermission>>(_page(items: const <ScopePermission>[])),
    );
    final controller = controllerUnderTest();

    // When
    await controller.search('nothing');

    // Then
    expect(currentState().query.isFiltered, isTrue);
  });

  test('GivenNoFilters_WhenLoaded_ThenTheQueryIsUnfiltered', () async {
    // Given
    answerWith(
      Success<Page<ScopePermission>>(_page(items: const <ScopePermission>[])),
    );
    final controller = controllerUnderTest();

    // When
    await controller.load();

    // Then
    expect(currentState().query.isFiltered, isFalse);
  });

  test('GivenFilters_WhenCleared_ThenTheFullListingIsRead', () async {
    // Given
    answerWith(Success<Page<ScopePermission>>(_page()));
    final controller = controllerUnderTest();
    await controller.search('read');

    // When
    await controller.clearFilters();

    // Then
    verify(
      () => repository.list(
        scopeId: 'scope-1',
        name: '',
        includeDeleted: false,
        pageNumber: 1,
      ),
    ).called(1);
  });

  test('GivenARequestInFlight_WhenAskedAgain_ThenOnlyOneIsSent', () async {
    // Given
    final pending = Completer<Result<Page<ScopePermission>>>();
    when(
      () => repository.list(
        scopeId: any(named: 'scopeId'),
        name: any(named: 'name'),
        includeDeleted: any(named: 'includeDeleted'),
        pageNumber: any(named: 'pageNumber'),
        pageSize: any(named: 'pageSize'),
      ),
    ).thenAnswer((_) => pending.future);
    final controller = controllerUnderTest();

    // When
    final first = controller.goToPage(2);
    final second = controller.goToPage(3);
    pending.complete(Success<Page<ScopePermission>>(_page()));
    await Future.wait<void>(<Future<void>>[first, second]);

    // Then
    verify(
      () => repository.list(
        scopeId: any(named: 'scopeId'),
        name: any(named: 'name'),
        includeDeleted: any(named: 'includeDeleted'),
        pageNumber: any(named: 'pageNumber'),
        pageSize: any(named: 'pageSize'),
      ),
    ).called(1);
  });
}
