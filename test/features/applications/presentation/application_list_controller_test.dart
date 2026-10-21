import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/core/network/envelope.dart';
import 'package:heimdall_ui/core/result/result.dart';
import 'package:heimdall_ui/features/applications/domain/application.dart';
import 'package:heimdall_ui/features/applications/domain/application_repository.dart';
import 'package:heimdall_ui/features/applications/presentation/application_list_controller.dart';
import 'package:heimdall_ui/features/auth/domain/session.dart';
import 'package:heimdall_ui/features/persons/domain/person.dart';
import 'package:heimdall_ui/features/persons/domain/person_repository.dart';
import 'package:heimdall_ui/features/profile/presentation/profile_controller.dart';
import 'package:mocktail/mocktail.dart';

import '../../../support/held_answer.dart';

class _MockApplicationRepository extends Mock
    implements ApplicationRepository {}

class _MockPersonRepository extends Mock implements PersonRepository {}

const _billing = Application(id: 'app-1', name: 'Billing', ownerId: 'person-1');

const _ada = Person(
  id: 'person-1',
  name: 'Ada',
  email: 'ada@example.com',
  role: Role.user,
);

Page<Application> _page({
  List<Application> items = const <Application>[_billing],
  int pageNumber = 1,
  int totalPages = 1,
}) => Page<Application>(
  items: items,
  pageNumber: pageNumber,
  pageSize: 20,
  totalItems: items.length,
  totalPages: totalPages,
);

void main() {
  late _MockApplicationRepository applications;
  late _MockPersonRepository persons;
  late ProviderContainer container;

  ApplicationListController controllerUnderTest() {
    container = ProviderContainer(
      overrides: <Override>[
        applicationRepositoryProvider.overrideWithValue(applications),
        personRepositoryProvider.overrideWithValue(persons),
      ],
    );
    addTearDown(container.dispose);

    return container.read(
      applicationListControllerProvider('scope-1').notifier,
    );
  }

  ApplicationListState currentState() =>
      container.read(applicationListControllerProvider('scope-1'));

  void answerWith(Result<Page<Application>> result) {
    when(
      () => applications.list(
        scopeId: any(named: 'scopeId'),
        name: any(named: 'name'),
        ownerId: any(named: 'ownerId'),
        includeDeleted: any(named: 'includeDeleted'),
        pageNumber: any(named: 'pageNumber'),
        pageSize: any(named: 'pageSize'),
      ),
    ).thenAnswer((_) async => result);
  }

  void answerOwnerWith(Result<Person> result) {
    when(
      () =>
          persons.getById(any(), includeDeleted: any(named: 'includeDeleted')),
    ).thenAnswer((_) async => result);
  }

  setUp(() {
    applications = _MockApplicationRepository();
    persons = _MockPersonRepository();
    answerOwnerWith(const Success<Person>(_ada));
  });

  test('GivenAPage_WhenLoaded_ThenTheApplicationsAreShown', () async {
    // Given
    answerWith(Success<Page<Application>>(_page()));
    final controller = controllerUnderTest();

    // When
    await controller.load();

    // Then
    expect(
      (currentState() as ApplicationListLoaded).page.items.single.name,
      'Billing',
    );
  });

  // FR-AP-08 — the owner is resolved to a person.
  test('GivenAResolvableOwner_WhenLoaded_ThenTheirNameIsShown', () async {
    // Given
    answerWith(Success<Page<Application>>(_page()));
    final controller = controllerUnderTest();

    // When
    await controller.load();

    // Then
    final state = currentState() as ApplicationListLoaded;
    expect(state.ownerLabel('person-1'), 'Ada');
  });

  // AF-20d — an owner that cannot be resolved is shown by its identifier.
  test(
    'GivenAnUnresolvableOwner_WhenLoaded_ThenTheIdentifierIsShown',
    () async {
      // Given
      answerWith(Success<Page<Application>>(_page()));
      answerOwnerWith(
        const FailureResult<Person>(
          Failure(kind: FailureKind.notFound, errors: <String>[]),
        ),
      );
      final controller = controllerUnderTest();

      // When
      await controller.load();

      // Then
      final state = currentState() as ApplicationListLoaded;
      expect(state.ownerLabel('person-1'), 'person-1');
    },
  );

  // A deleted person still owns applications, and naming them beats an id.
  test('GivenAnOwner_WhenResolved_ThenDeletedPersonsAreIncluded', () async {
    // Given
    answerWith(Success<Page<Application>>(_page()));
    final controller = controllerUnderTest();

    // When
    await controller.load();

    // Then
    verify(() => persons.getById('person-1', includeDeleted: true)).called(1);
  });

  test('GivenOneOwnerAcrossManyRows_WhenLoaded_ThenTheyAreReadOnce', () async {
    // Given
    answerWith(
      Success<Page<Application>>(
        _page(
          items: const <Application>[
            _billing,
            Application(id: 'app-2', name: 'Portal', ownerId: 'person-1'),
            Application(id: 'app-3', name: 'Reports', ownerId: 'person-1'),
          ],
        ),
      ),
    );
    final controller = controllerUnderTest();

    // When
    await controller.load();

    // Then
    verify(
      () =>
          persons.getById(any(), includeDeleted: any(named: 'includeDeleted')),
    ).called(1);
  });

  test(
    'GivenAnAlreadyResolvedOwner_WhenPaged_ThenTheyAreNotReadAgain',
    () async {
      // Given
      answerWith(Success<Page<Application>>(_page(totalPages: 3)));
      final controller = controllerUnderTest();
      await controller.load();

      // When
      await controller.goToPage(2);

      // Then
      verify(
        () => persons.getById(
          any(),
          includeDeleted: any(named: 'includeDeleted'),
        ),
      ).called(1);
    },
  );

  test('GivenASearch_WhenSubmitted_ThenTheNameIsSent', () async {
    // Given
    answerWith(Success<Page<Application>>(_page()));
    final controller = controllerUnderTest();

    // When
    await controller.search('Billing');

    // Then
    verify(
      () => applications.list(
        scopeId: 'scope-1',
        name: 'Billing',
        includeDeleted: false,
        pageNumber: 1,
      ),
    ).called(1);
  });

  test('GivenAPageOtherThanTheFirst_WhenSearched_ThenPagingResets', () async {
    // Given
    answerWith(Success<Page<Application>>(_page(totalPages: 5)));
    final controller = controllerUnderTest();
    await controller.load();
    await controller.goToPage(3);

    // When
    await controller.search('Billing');

    // Then
    expect(currentState().query.pageNumber, 1);
  });

  test('GivenIncludeDeleted_WhenToggled_ThenTheFlagIsSent', () async {
    // Given
    answerWith(Success<Page<Application>>(_page()));
    final controller = controllerUnderTest();

    // When
    await controller.setIncludeDeleted(true);

    // Then
    verify(
      () => applications.list(
        scopeId: 'scope-1',
        name: '',
        includeDeleted: true,
        pageNumber: 1,
      ),
    ).called(1);
  });

  // AF-20c — a scope this admin does not own.
  test('GivenAForbiddenScope_WhenLoaded_ThenStateIsForbidden', () async {
    // Given
    answerWith(
      const FailureResult<Page<Application>>(
        Failure(kind: FailureKind.forbidden, errors: <String>[]),
      ),
    );
    final controller = controllerUnderTest();

    // When
    await controller.load();

    // Then
    expect((currentState() as ApplicationListFailed).isForbidden, isTrue);
  });

  // AF-20a — a filtered listing knows it is filtered.
  test('GivenASearch_WhenApplied_ThenTheQueryIsFiltered', () async {
    // Given
    answerWith(Success<Page<Application>>(_page(items: const <Application>[])));
    final controller = controllerUnderTest();

    // When
    await controller.search('nothing');

    // Then
    expect(currentState().query.isFiltered, isTrue);
  });

  test('GivenFilters_WhenCleared_ThenTheFullListingIsRead', () async {
    // Given
    answerWith(Success<Page<Application>>(_page()));
    final controller = controllerUnderTest();
    await controller.search('Billing');

    // When
    await controller.clearFilters();

    // Then
    verify(
      () => applications.list(
        scopeId: 'scope-1',
        name: '',
        includeDeleted: false,
        pageNumber: 1,
      ),
    ).called(1);
  });

  // A read that merely failed says nothing about the person, so it is asked
  // again rather than pinning them to their identifier for the session.
  test('GivenAFailedOwnerRead_WhenPaged_ThenItIsAskedAgain', () async {
    // Given
    answerWith(Success<Page<Application>>(_page(totalPages: 3)));
    answerOwnerWith(
      const FailureResult<Person>(
        Failure(kind: FailureKind.network, errors: <String>[]),
      ),
    );
    final controller = controllerUnderTest();
    await controller.load();
    answerOwnerWith(const Success<Person>(_ada));

    // When
    await controller.goToPage(2);

    // Then
    final state = currentState() as ApplicationListLoaded;
    expect(state.ownerLabel('person-1'), 'Ada');
  });

  // The API saying there is nobody is an answer, and is not asked again.
  test('GivenAMissingOwner_WhenPaged_ThenTheyAreNotReadAgain', () async {
    // Given
    answerWith(Success<Page<Application>>(_page(totalPages: 3)));
    answerOwnerWith(
      const FailureResult<Person>(
        Failure(kind: FailureKind.notFound, errors: <String>[]),
      ),
    );
    final controller = controllerUnderTest();
    await controller.load();

    // When
    await controller.goToPage(2);

    // Then
    verify(
      () =>
          persons.getById(any(), includeDeleted: any(named: 'includeDeleted')),
    ).called(1);
  });

  // A reload is where a renamed owner should show their new name.
  test('GivenARenamedOwner_WhenReloaded_ThenTheNewNameIsShown', () async {
    // Given
    answerWith(Success<Page<Application>>(_page()));
    final controller = controllerUnderTest();
    await controller.load();
    answerOwnerWith(
      const Success<Person>(
        Person(
          id: 'person-1',
          name: 'Ada Lovelace',
          email: 'ada@example.com',
          role: Role.user,
        ),
      ),
    );

    // When
    await controller.load();

    // Then
    final state = currentState() as ApplicationListLoaded;
    expect(state.ownerLabel('person-1'), 'Ada Lovelace');
  });

  test(
    'GivenAnOwnerReadThatThrows_WhenLoaded_ThenTheStateIsFailedAsUnexpected',
    () async {
      // Given
      answerWith(Success<Page<Application>>(_page()));
      when(
        () => persons.getById(
          any(),
          includeDeleted: any(named: 'includeDeleted'),
        ),
      ).thenAnswer(
        (_) =>
            Future<Result<Person>>.error(const FormatException('not a person')),
      );
      final controller = controllerUnderTest();

      // When
      await controller.load();

      // Then
      final state = currentState();
      expect(state, isA<ApplicationListFailed>());
      final failure = (state as ApplicationListFailed).failure;
      expect(failure.kind, FailureKind.unknown);
      expect(
        failure.displayMessage,
        'The API returned an unexpected response.',
      );
    },
  );

  // #157 — a search queued during a load, then a second change: the request
  // that follows the load carries both.
  test('GivenASearchQueuedDuringALoad_WhenIncludeDeletedIsToggled_ThenTheLastRequestCarriesBoth', () async {
    // Given
    final first = Completer<Result<Page<Application>>>();
    when(
      () => applications.list(
        scopeId: any(named: 'scopeId'),
        name: any(named: 'name'),
        ownerId: any(named: 'ownerId'),
        includeDeleted: any(named: 'includeDeleted'),
        pageNumber: any(named: 'pageNumber'),
        pageSize: any(named: 'pageSize'),
      ),
    ).thenAnswer(
      heldFirstAnswer(first, () => Success<Page<Application>>(_page())),
    );
    final controller = controllerUnderTest();
    final loading = controller.load();

    // When
    unawaited(controller.search('abc'));
    unawaited(controller.setIncludeDeleted(true));
    first.complete(Success<Page<Application>>(_page()));
    await loading;

    // Then
    verify(
      () => applications.list(
        scopeId: 'scope-1',
        name: 'abc',
        includeDeleted: true,
        pageNumber: 1,
      ),
    ).called(1);
    expect(currentState().query.name, 'abc');
    expect(currentState().query.includeDeleted, isTrue);
  });
}
