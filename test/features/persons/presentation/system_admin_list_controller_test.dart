import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/core/network/envelope.dart';
import 'package:heimdall_ui/core/result/result.dart';
import 'package:heimdall_ui/features/persons/domain/person.dart';
import 'package:heimdall_ui/features/persons/domain/person_repository.dart';
import 'package:heimdall_ui/features/persons/presentation/system_admin_list_controller.dart';
import 'package:heimdall_ui/features/profile/presentation/profile_controller.dart';
import 'package:mocktail/mocktail.dart';

class _MockPersonRepository extends Mock implements PersonRepository {}

const _ada = PersonSummary(
  id: 'admin-1',
  name: 'Ada',
  email: 'ada@example.com',
);

Page<PersonSummary> _page({
  List<PersonSummary> items = const <PersonSummary>[_ada],
  int pageNumber = 1,
  int totalPages = 1,
}) => Page<PersonSummary>(
  items: items,
  pageNumber: pageNumber,
  pageSize: 20,
  totalItems: items.length,
  totalPages: totalPages,
);

void main() {
  late _MockPersonRepository repository;
  late ProviderContainer container;
  late ProviderSubscription<SystemAdminListState> subscription;

  SystemAdminListController controllerUnderTest() {
    container = ProviderContainer(
      overrides: <Override>[
        personRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    // An autoDispose provider needs a listener to stay alive between reads.
    subscription = container.listen(
      systemAdminListControllerProvider,
      (_, _) {},
    );

    return container.read(systemAdminListControllerProvider.notifier);
  }

  SystemAdminListState currentState() =>
      container.read(systemAdminListControllerProvider);

  void answerWith(Future<Result<Page<PersonSummary>>> Function() answer) {
    when(
      () => repository.listSystemAdmins(
        name: any(named: 'name'),
        email: any(named: 'email'),
        pageNumber: any(named: 'pageNumber'),
        pageSize: any(named: 'pageSize'),
      ),
    ).thenAnswer((_) => answer());
  }

  void failWith(Object error) {
    when(
      () => repository.listSystemAdmins(
        name: any(named: 'name'),
        email: any(named: 'email'),
        pageNumber: any(named: 'pageNumber'),
        pageSize: any(named: 'pageSize'),
      ),
    ).thenAnswer((_) => Future<Result<Page<PersonSummary>>>.error(error));
  }

  setUp(() {
    repository = _MockPersonRepository();
  });

  test('GivenAPage_WhenLoaded_ThenTheAdminsAreShown', () async {
    // Given
    answerWith(() async => Success<Page<PersonSummary>>(_page()));
    final controller = controllerUnderTest();

    // When
    await controller.load();

    // Then
    expect(
      (currentState() as SystemAdminListLoaded).page.items.single.name,
      'Ada',
    );
  });

  test('GivenPageTwo_WhenSearched_ThenTheFirstPageIsAsked', () async {
    // Given
    answerWith(
      () async =>
          Success<Page<PersonSummary>>(_page(pageNumber: 2, totalPages: 2)),
    );
    final controller = controllerUnderTest();
    await controller.goToPage(2);

    // When
    await controller.search(name: 'Ada');

    // Then
    verify(
      () => repository.listSystemAdmins(
        name: 'Ada',
        email: '',
        pageNumber: 1,
        pageSize: any(named: 'pageSize'),
      ),
    ).called(1);
  });

  test('GivenALoadInFlight_WhenTwoSearchesArrive_ThenBothFiltersReachTheLastRequest', () async {
    // Given
    final first = Completer<Result<Page<PersonSummary>>>();
    var calls = 0;
    answerWith(() {
      calls++;

      return calls == 1
          ? first.future
          : Future.value(Success<Page<PersonSummary>>(_page()));
    });
    final controller = controllerUnderTest();
    final loading = controller.load();

    // When
    unawaited(controller.search(name: 'Ada'));
    unawaited(controller.search(email: 'ada@example.com'));
    first.complete(Success<Page<PersonSummary>>(_page()));
    await loading;
    await pumpEventQueue();

    // Then
    verify(
      () => repository.listSystemAdmins(
        name: 'Ada',
        email: 'ada@example.com',
        pageNumber: 1,
        pageSize: any(named: 'pageSize'),
      ),
    ).called(1);
    expect(calls, 2);
  });

  test(
    'GivenAnEmptyPagePastTheEnd_WhenLoaded_ThenTheLastPageIsAsked',
    () async {
      // Given
      answerWith(
        () async => Success<Page<PersonSummary>>(
          _page(items: const <PersonSummary>[], pageNumber: 2),
        ),
      );
      when(
        () => repository.listSystemAdmins(
          name: any(named: 'name'),
          email: any(named: 'email'),
          pageNumber: 1,
          pageSize: any(named: 'pageSize'),
        ),
      ).thenAnswer((_) async => Success<Page<PersonSummary>>(_page()));
      final controller = controllerUnderTest();

      // When
      await controller.goToPage(2);

      // Then
      final state = currentState() as SystemAdminListLoaded;
      expect(state.query.pageNumber, 1);
      expect(state.page.items, <PersonSummary>[_ada]);
    },
  );

  test(
    'GivenAnEmptyPageFarPastTheEnd_WhenLoaded_ThenTheLastRealPageIsAsked',
    () async {
      // Given
      answerWith(
        () async => Success<Page<PersonSummary>>(
          _page(items: const <PersonSummary>[], pageNumber: 5, totalPages: 2),
        ),
      );
      when(
        () => repository.listSystemAdmins(
          name: any(named: 'name'),
          email: any(named: 'email'),
          pageNumber: 2,
          pageSize: any(named: 'pageSize'),
        ),
      ).thenAnswer(
        (_) async =>
            Success<Page<PersonSummary>>(_page(pageNumber: 2, totalPages: 2)),
      );
      final controller = controllerUnderTest();

      // When
      await controller.goToPage(5);

      // Then
      verify(
        () => repository.listSystemAdmins(
          name: '',
          email: '',
          pageNumber: 2,
          pageSize: any(named: 'pageSize'),
        ),
      ).called(1);
      verifyNever(
        () => repository.listSystemAdmins(
          name: any(named: 'name'),
          email: any(named: 'email'),
          pageNumber: 4,
          pageSize: any(named: 'pageSize'),
        ),
      );
      expect((currentState() as SystemAdminListLoaded).query.pageNumber, 2);
    },
  );

  test('GivenA403_WhenLoaded_ThenTheStateIsForbidden', () async {
    // Given
    answerWith(
      () async => const FailureResult<Page<PersonSummary>>(
        Failure(kind: FailureKind.forbidden, errors: <String>['No.']),
      ),
    );
    final controller = controllerUnderTest();

    // When
    await controller.load();

    // Then
    expect((currentState() as SystemAdminListFailed).isForbidden, isTrue);
  });

  test('GivenFilters_WhenTheScreenIsLeft_ThenTheListStartsFresh', () async {
    // Given
    answerWith(() async => Success<Page<PersonSummary>>(_page()));
    final controller = controllerUnderTest();
    await controller.search(name: 'Ada');

    // When
    subscription.close();
    await pumpEventQueue();

    // Then
    expect(currentState().query.name, '');
  });

  test('GivenARepositoryThatThrowsAFormatException_WhenLoaded_ThenTheStateIsFailedAsUnexpected', () async {
    // Given
    failWith(const FormatException('not the shape of a page'));
    final controller = controllerUnderTest();

    // When
    await controller.load();

    // Then
    final state = currentState();
    expect(state, isA<SystemAdminListFailed>());
    final failure = (state as SystemAdminListFailed).failure;
    expect(failure.kind, FailureKind.unknown);
    expect(failure.displayMessage, 'The API returned an unexpected response.');
  });
}
