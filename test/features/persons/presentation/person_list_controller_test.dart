import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/core/network/envelope.dart';
import 'package:heimdall_ui/core/result/result.dart';
import 'package:heimdall_ui/features/auth/domain/session.dart';
import 'package:heimdall_ui/features/persons/domain/person.dart';
import 'package:heimdall_ui/features/persons/domain/person_repository.dart';
import 'package:heimdall_ui/features/persons/presentation/person_list_controller.dart';
import 'package:heimdall_ui/features/profile/presentation/profile_controller.dart';
import 'package:mocktail/mocktail.dart';

import '../../../support/late_answer.dart';

class _MockPersonRepository extends Mock implements PersonRepository {}

const _ada = Person(
  id: 'person-1',
  name: 'Ada',
  email: 'ada@example.com',
  role: Role.user,
);

Page<Person> _page({
  List<Person> items = const <Person>[_ada],
  int pageNumber = 1,
  int totalPages = 1,
}) => Page<Person>(
  items: items,
  pageNumber: pageNumber,
  pageSize: 20,
  totalItems: items.length,
  totalPages: totalPages,
);

void main() {
  late _MockPersonRepository repository;
  late ProviderContainer container;

  PersonListController controllerUnderTest() {
    container = ProviderContainer(
      overrides: <Override>[
        personRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    return container.read(personListControllerProvider('scope-1').notifier);
  }

  PersonListState currentState() =>
      container.read(personListControllerProvider('scope-1'));

  void answerWith(Result<Page<Person>> result) {
    when(
      () => repository.listScopePersons(
        scopeId: any(named: 'scopeId'),
        name: any(named: 'name'),
        email: any(named: 'email'),
        includeDeleted: any(named: 'includeDeleted'),
        pageNumber: any(named: 'pageNumber'),
        pageSize: any(named: 'pageSize'),
      ),
    ).thenAnswer((_) async => result);
  }

  void failWith(Object error) {
    when(
      () => repository.listScopePersons(
        scopeId: any(named: 'scopeId'),
        name: any(named: 'name'),
        email: any(named: 'email'),
        includeDeleted: any(named: 'includeDeleted'),
        pageNumber: any(named: 'pageNumber'),
        pageSize: any(named: 'pageSize'),
      ),
    ).thenAnswer((_) => Future<Result<Page<Person>>>.error(error));
  }

  setUp(() {
    repository = _MockPersonRepository();
  });

  test('GivenAPage_WhenLoaded_ThenThePersonsAreShown', () async {
    // Given
    answerWith(Success<Page<Person>>(_page()));
    final controller = controllerUnderTest();

    // When
    await controller.load();

    // Then
    expect((currentState() as PersonListLoaded).page.items.single.name, 'Ada');
  });

  test('GivenAScope_WhenLoaded_ThenThatScopeIsRead', () async {
    // Given
    answerWith(Success<Page<Person>>(_page()));
    final controller = controllerUnderTest();

    // When
    await controller.load();

    // Then
    verify(
      () => repository.listScopePersons(
        scopeId: 'scope-1',
        name: '',
        email: '',
        includeDeleted: false,
        pageNumber: 1,
      ),
    ).called(1);
  });

  test('GivenASearch_WhenSubmitted_ThenBothFiltersAreSent', () async {
    // Given
    answerWith(Success<Page<Person>>(_page()));
    final controller = controllerUnderTest();

    // When
    await controller.search(name: 'Ada', email: 'ada@example.com');

    // Then
    verify(
      () => repository.listScopePersons(
        scopeId: 'scope-1',
        name: 'Ada',
        email: 'ada@example.com',
        includeDeleted: false,
        pageNumber: 1,
      ),
    ).called(1);
  });

  // AF-16d — a new search starts at the first page.
  test('GivenAPageOtherThanTheFirst_WhenSearched_ThenPagingResets', () async {
    // Given
    answerWith(Success<Page<Person>>(_page(totalPages: 5)));
    final controller = controllerUnderTest();
    await controller.load();
    await controller.goToPage(3);

    // When
    await controller.search(name: 'Ada');

    // Then
    expect(currentState().query.pageNumber, 1);
  });

  test(
    'GivenAPageOtherThanTheFirst_WhenIncludeDeletedToggled_ThenPagingResets',
    () async {
      // Given
      answerWith(Success<Page<Person>>(_page(totalPages: 5)));
      final controller = controllerUnderTest();
      await controller.load();
      await controller.goToPage(3);

      // When
      await controller.setIncludeDeleted(true);

      // Then
      expect(currentState().query.pageNumber, 1);
    },
  );

  test('GivenAPageChange_WhenRequested_ThenThatPageIsRead', () async {
    // Given
    answerWith(Success<Page<Person>>(_page(totalPages: 4)));
    final controller = controllerUnderTest();
    await controller.load();

    // When
    await controller.goToPage(2);

    // Then
    verify(
      () => repository.listScopePersons(
        scopeId: 'scope-1',
        name: '',
        email: '',
        includeDeleted: false,
        pageNumber: 2,
      ),
    ).called(1);
  });

  // AF-16b — the query that failed is kept, so the retry asks it again.
  test('GivenAFailedRequest_WhenSearched_ThenTheFiltersSurvive', () async {
    // Given
    answerWith(
      const FailureResult<Page<Person>>(
        Failure(kind: FailureKind.network, errors: <String>[]),
      ),
    );
    final controller = controllerUnderTest();

    // When
    await controller.search(name: 'Ada');

    // Then
    expect(currentState().query.name, 'Ada');
  });

  // AF-16c — a Scope Admin opening a scope they do not own.
  test('GivenAForbiddenScope_WhenLoaded_ThenStateIsForbidden', () async {
    // Given
    answerWith(
      const FailureResult<Page<Person>>(
        Failure(kind: FailureKind.forbidden, errors: <String>[]),
      ),
    );
    final controller = controllerUnderTest();

    // When
    await controller.load();

    // Then
    expect((currentState() as PersonListFailed).isForbidden, isTrue);
  });

  test('GivenARefusedListing_WhenLoaded_ThenApiErrorsAreKept', () async {
    // Given
    answerWith(
      const FailureResult<Page<Person>>(
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
    expect((currentState() as PersonListFailed).failure.errors, <String>[
      'Page size is too large.',
    ]);
  });

  // AF-16a — a filtered listing knows it is filtered.
  test('GivenASearch_WhenApplied_ThenTheQueryIsFiltered', () async {
    // Given
    answerWith(Success<Page<Person>>(_page(items: const <Person>[])));
    final controller = controllerUnderTest();

    // When
    await controller.search(email: 'nobody@example.com');

    // Then
    expect(currentState().query.isFiltered, isTrue);
  });

  test('GivenNoFilters_WhenLoaded_ThenTheQueryIsUnfiltered', () async {
    // Given
    answerWith(Success<Page<Person>>(_page(items: const <Person>[])));
    final controller = controllerUnderTest();

    // When
    await controller.load();

    // Then
    expect(currentState().query.isFiltered, isFalse);
  });

  test('GivenFilters_WhenCleared_ThenTheFullListingIsRead', () async {
    // Given
    answerWith(Success<Page<Person>>(_page()));
    final controller = controllerUnderTest();
    await controller.search(name: 'Ada');

    // When
    await controller.clearFilters();

    // Then
    verify(
      () => repository.listScopePersons(
        scopeId: 'scope-1',
        name: '',
        email: '',
        includeDeleted: false,
        pageNumber: 1,
      ),
    ).called(1);
  });

  test(
    'GivenARequestInFlight_WhenAskedAgain_ThenTheNewestWaitsItsTurn',
    () async {
      // Given
      final pending = Completer<Result<Page<Person>>>();
      when(
        () => repository.listScopePersons(
          scopeId: any(named: 'scopeId'),
          name: any(named: 'name'),
          email: any(named: 'email'),
          includeDeleted: any(named: 'includeDeleted'),
          pageNumber: any(named: 'pageNumber'),
          pageSize: any(named: 'pageSize'),
        ),
      ).thenAnswer((_) => pending.future);
      final controller = controllerUnderTest();

      // When
      final first = controller.goToPage(2);
      final second = controller.goToPage(3);

      // Then — the second waits for the first rather than racing it
      verify(
        () => repository.listScopePersons(
          scopeId: any(named: 'scopeId'),
          name: any(named: 'name'),
          email: any(named: 'email'),
          includeDeleted: any(named: 'includeDeleted'),
          pageNumber: any(named: 'pageNumber'),
          pageSize: any(named: 'pageSize'),
        ),
      ).called(1);

      // …and is asked once the first is answered, rather than dropped
      pending.complete(Success<Page<Person>>(_page()));
      await Future.wait<void>(<Future<void>>[first, second]);
      verify(
        () => repository.listScopePersons(
          scopeId: any(named: 'scopeId'),
          name: any(named: 'name'),
          email: any(named: 'email'),
          includeDeleted: any(named: 'includeDeleted'),
          pageNumber: any(named: 'pageNumber'),
          pageSize: any(named: 'pageSize'),
        ),
      ).called(1);
    },
  );

  test('GivenARepositoryThatThrowsAFormatException_WhenLoaded_ThenTheStateIsFailedAsUnexpected', () async {
    // Given
    failWith(const FormatException('not the shape of a page'));
    final controller = controllerUnderTest();

    // When
    await controller.load();

    // Then
    final state = currentState();
    expect(state, isA<PersonListFailed>());
    final failure = (state as PersonListFailed).failure;
    expect(failure.kind, FailureKind.unknown);
    expect(failure.displayMessage, 'The API returned an unexpected response.');
  });

  test('GivenARepositoryThatThrowsATypeError_WhenLoaded_ThenTheStateIsFailedAsUnexpected', () async {
    // Given
    when(
      () => repository.listScopePersons(
        scopeId: any(named: 'scopeId'),
        name: any(named: 'name'),
        email: any(named: 'email'),
        includeDeleted: any(named: 'includeDeleted'),
        pageNumber: any(named: 'pageNumber'),
        pageSize: any(named: 'pageSize'),
      ),
    ).thenAnswer((_) async => (null as dynamic) as Result<Page<Person>>);
    final controller = controllerUnderTest();

    // When
    await controller.load();

    // Then
    final state = currentState();
    expect(state, isA<PersonListFailed>());
    final failure = (state as PersonListFailed).failure;
    expect(failure.kind, FailureKind.unknown);
    expect(failure.displayMessage, 'The API returned an unexpected response.');
  });

  test('GivenASearchQueuedDuringAThrowingRequest_WhenItFails_ThenTheSearchStillRuns', () async {
    // Given
    final first = Completer<Result<Page<Person>>>();
    var calls = 0;
    when(
      () => repository.listScopePersons(
        scopeId: any(named: 'scopeId'),
        name: any(named: 'name'),
        email: any(named: 'email'),
        includeDeleted: any(named: 'includeDeleted'),
        pageNumber: any(named: 'pageNumber'),
        pageSize: any(named: 'pageSize'),
      ),
    ).thenAnswer((_) {
      calls++;

      return calls == 1
          ? first.future
          : Future.value(Success<Page<Person>>(_page()));
    });
    final controller = controllerUnderTest();
    final loading = controller.load();

    // When
    unawaited(controller.search(name: 'Ada'));
    first.completeError(const FormatException('not the shape of a page'));
    await loading;
    await pumpEventQueue();

    // Then
    verify(
      () => repository.listScopePersons(
        scopeId: 'scope-1',
        name: 'Ada',
        email: '',
        includeDeleted: false,
        pageNumber: 1,
      ),
    ).called(1);
    expect(currentState(), isA<PersonListLoaded>());
  });

  test(
    'GivenARepositoryThatThrowsAnotherError_WhenLoaded_ThenItPropagates',
    () async {
      // Given
      failWith(StateError('a bug, not a bad answer'));
      final controller = controllerUnderTest();

      // When / Then
      await expectLater(controller.load(), throwsA(isA<StateError>()));
    },
  );

  // A sign-out resets the listing while its request is in flight, and the late
  // answer, the previous session's people, must not land in the reset state.
  test(
    'GivenALoadInFlight_WhenTheSessionResets_ThenTheAnswerIsDropped',
    () async {
      // Given
      final answer = Completer<Result<Page<Person>>>();
      when(
        () => repository.listScopePersons(
          scopeId: any(named: 'scopeId'),
          name: any(named: 'name'),
          email: any(named: 'email'),
          includeDeleted: any(named: 'includeDeleted'),
          pageNumber: any(named: 'pageNumber'),
          pageSize: any(named: 'pageSize'),
        ),
      ).thenAnswer((_) => answer.future);
      final controller = controllerUnderTest();

      // When
      await answerAfterReset(
        container,
        personListControllerProvider('scope-1'),
        reset: personListControllerProvider,
        start: controller.load,
        answer: () => answer.complete(Success<Page<Person>>(_page())),
      );

      // Then
      expect(currentState(), isA<PersonListLoading>());
    },
  );
}
