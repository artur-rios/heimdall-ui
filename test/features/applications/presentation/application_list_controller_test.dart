import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  // AF-20b — the query that failed is kept, so the retry asks it again.
  test('GivenAFailedRequest_WhenSearched_ThenTheFiltersSurvive', () async {
    // Given
    answerWith(
      const FailureResult<Page<Application>>(
        Failure(kind: FailureKind.network, errors: <String>[]),
      ),
    );
    final controller = controllerUnderTest();

    // When
    await controller.search('Billing');

    // Then
    expect(currentState().query.name, 'Billing');
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

  test('GivenARequestInFlight_WhenAskedAgain_ThenOnlyOneIsSent', () async {
    // Given
    final pending = Completer<Result<Page<Application>>>();
    when(
      () => applications.list(
        scopeId: any(named: 'scopeId'),
        name: any(named: 'name'),
        ownerId: any(named: 'ownerId'),
        includeDeleted: any(named: 'includeDeleted'),
        pageNumber: any(named: 'pageNumber'),
        pageSize: any(named: 'pageSize'),
      ),
    ).thenAnswer((_) => pending.future);
    final controller = controllerUnderTest();

    // When
    final first = controller.goToPage(2);
    final second = controller.goToPage(3);
    pending.complete(Success<Page<Application>>(_page()));
    await Future.wait<void>(<Future<void>>[first, second]);

    // Then
    verify(
      () => applications.list(
        scopeId: any(named: 'scopeId'),
        name: any(named: 'name'),
        ownerId: any(named: 'ownerId'),
        includeDeleted: any(named: 'includeDeleted'),
        pageNumber: any(named: 'pageNumber'),
        pageSize: any(named: 'pageSize'),
      ),
    ).called(1);
  });
}
