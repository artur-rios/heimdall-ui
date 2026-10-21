import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/core/network/envelope.dart';
import 'package:heimdall_ui/core/result/result.dart';
import 'package:heimdall_ui/features/scopes/domain/scope.dart';
import 'package:heimdall_ui/features/scopes/domain/scope_repository.dart';
import 'package:heimdall_ui/features/scopes/presentation/scope_list_controller.dart';
import 'package:mocktail/mocktail.dart';

import '../../../support/held_answer.dart';

class _MockScopeRepository extends Mock implements ScopeRepository {}

const _acme = Scope(id: 'scope-1', name: 'Acme', description: 'First tenant');

Page<Scope> _page({
  List<Scope> items = const <Scope>[_acme],
  int pageNumber = 1,
  int totalPages = 1,
}) => Page<Scope>(
  items: items,
  pageNumber: pageNumber,
  pageSize: 20,
  totalItems: items.length,
  totalPages: totalPages,
);

void main() {
  late _MockScopeRepository repository;
  late ProviderContainer container;

  ScopeListController controllerUnderTest() {
    container = ProviderContainer(
      overrides: <Override>[
        scopeRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    return container.read(scopeListControllerProvider.notifier);
  }

  void answerWith(Result<Page<Scope>> result) {
    when(
      () => repository.list(
        name: any(named: 'name'),
        includeDeleted: any(named: 'includeDeleted'),
        pageNumber: any(named: 'pageNumber'),
        pageSize: any(named: 'pageSize'),
      ),
    ).thenAnswer((_) async => result);
  }

  setUp(() {
    repository = _MockScopeRepository();
  });

  test('GivenAPage_WhenLoaded_ThenStateIsLoaded', () async {
    // Given
    answerWith(Success<Page<Scope>>(_page()));
    final controller = controllerUnderTest();

    // When
    await controller.load();

    // Then
    final state = container.read(scopeListControllerProvider);
    expect((state as ScopeListLoaded).page.items.single.name, 'Acme');
  });

  test('GivenASearch_WhenSubmitted_ThenTheNameIsSent', () async {
    // Given
    answerWith(Success<Page<Scope>>(_page()));
    final controller = controllerUnderTest();

    // When
    await controller.search('Acme');

    // Then
    verify(
      () => repository.list(name: 'Acme', includeDeleted: false, pageNumber: 1),
    ).called(1);
  });

  // AF-10d — a new search starts at the first page.
  test('GivenAPageOtherThanTheFirst_WhenSearched_ThenPagingResets', () async {
    // Given
    answerWith(Success<Page<Scope>>(_page(pageNumber: 3, totalPages: 5)));
    final controller = controllerUnderTest();
    await controller.load();
    await controller.goToPage(3);

    // When
    await controller.search('Acme');

    // Then
    expect(container.read(scopeListControllerProvider).query.pageNumber, 1);
  });

  // AF-10d — as does changing what is included.
  test(
    'GivenAPageOtherThanTheFirst_WhenIncludeDeletedToggled_ThenPagingResets',
    () async {
      // Given
      answerWith(Success<Page<Scope>>(_page(pageNumber: 3, totalPages: 5)));
      final controller = controllerUnderTest();
      await controller.load();
      await controller.goToPage(3);

      // When
      await controller.setIncludeDeleted(true);

      // Then
      expect(container.read(scopeListControllerProvider).query.pageNumber, 1);
    },
  );

  test('GivenIncludeDeleted_WhenToggled_ThenTheFlagIsSent', () async {
    // Given
    answerWith(Success<Page<Scope>>(_page()));
    final controller = controllerUnderTest();

    // When
    await controller.setIncludeDeleted(true);

    // Then
    verify(() => repository.list(name: '', includeDeleted: true, pageNumber: 1))
        .called(1);
  });

  test('GivenAPageChange_WhenRequested_ThenThatPageIsRead', () async {
    // Given
    answerWith(Success<Page<Scope>>(_page(totalPages: 4)));
    final controller = controllerUnderTest();
    await controller.load();

    // When
    await controller.goToPage(2);

    // Then
    verify(
      () => repository.list(name: '', includeDeleted: false, pageNumber: 2),
    ).called(1);
  });

  test('GivenARefusedListing_WhenLoaded_ThenApiErrorsAreKept', () async {
    // Given
    answerWith(
      const FailureResult<Page<Scope>>(
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
    final state = container.read(scopeListControllerProvider);
    expect((state as ScopeListFailed).failure.errors, <String>[
      'Page size is too large.',
    ]);
  });

  // AF-10a — a filtered listing knows it is filtered, which is what tells "no
  // matches" from "nothing here yet".
  test('GivenASearch_WhenApplied_ThenTheQueryIsFiltered', () async {
    // Given
    answerWith(Success<Page<Scope>>(_page(items: const <Scope>[])));
    final controller = controllerUnderTest();

    // When
    await controller.search('nothing');

    // Then
    expect(
      container.read(scopeListControllerProvider).query.isFiltered,
      isTrue,
    );
  });

  test('GivenNoFilters_WhenLoaded_ThenTheQueryIsUnfiltered', () async {
    // Given
    answerWith(Success<Page<Scope>>(_page(items: const <Scope>[])));
    final controller = controllerUnderTest();

    // When
    await controller.load();

    // Then
    expect(
      container.read(scopeListControllerProvider).query.isFiltered,
      isFalse,
    );
  });

  test('GivenFilters_WhenCleared_ThenTheFullListingIsRead', () async {
    // Given
    answerWith(Success<Page<Scope>>(_page()));
    final controller = controllerUnderTest();
    await controller.search('Acme');

    // When
    await controller.clearFilters();

    // Then
    verify(
      () => repository.list(name: '', includeDeleted: false, pageNumber: 1),
    ).called(1);
  });

  // #157 — a search queued during a load, then a second change: the request
  // that follows the load carries both.
  test('GivenASearchQueuedDuringALoad_WhenIncludeDeletedIsToggled_ThenTheLastRequestCarriesBoth', () async {
    // Given
    final first = Completer<Result<Page<Scope>>>();
    when(
      () => repository.list(
        name: any(named: 'name'),
        includeDeleted: any(named: 'includeDeleted'),
        pageNumber: any(named: 'pageNumber'),
        pageSize: any(named: 'pageSize'),
      ),
    ).thenAnswer(heldFirstAnswer(first, () => Success<Page<Scope>>(_page())));
    final controller = controllerUnderTest();
    final loading = controller.load();

    // When
    unawaited(controller.search('abc'));
    unawaited(controller.setIncludeDeleted(true));
    first.complete(Success<Page<Scope>>(_page()));
    await loading;

    // Then
    verify(
      () => repository.list(name: 'abc', includeDeleted: true, pageNumber: 1),
    ).called(1);
    final query = container.read(scopeListControllerProvider).query;
    expect(query.name, 'abc');
    expect(query.includeDeleted, isTrue);
  });
}
