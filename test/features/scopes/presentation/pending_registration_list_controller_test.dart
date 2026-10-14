import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/core/network/envelope.dart';
import 'package:heimdall_ui/core/result/result.dart';
import 'package:heimdall_ui/features/scopes/domain/pending_registration.dart';
import 'package:heimdall_ui/features/scopes/domain/pending_registration_repository.dart';
import 'package:heimdall_ui/features/scopes/presentation/pending_registration_list_controller.dart';
import 'package:mocktail/mocktail.dart';

class _MockPendingRegistrationRepository extends Mock
    implements PendingRegistrationRepository {}

const _ada = PendingRegistration(
  id: 'r1',
  name: 'Ada Lovelace',
  email: 'ada@example.com',
  attemptsLeft: 10,
  expired: false,
);

Page<PendingRegistration> _page({
  List<PendingRegistration> items = const <PendingRegistration>[_ada],
  int pageNumber = 1,
  int totalPages = 1,
}) => Page<PendingRegistration>(
  items: items,
  pageNumber: pageNumber,
  pageSize: 20,
  totalItems: items.length,
  totalPages: totalPages,
);

void main() {
  late _MockPendingRegistrationRepository repository;
  late ProviderContainer container;

  PendingRegistrationListController controllerUnderTest() {
    container = ProviderContainer(
      overrides: <Override>[
        pendingRegistrationRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    return container.read(
      pendingRegistrationListControllerProvider('s1').notifier,
    );
  }

  PendingRegistrationListState currentState() =>
      container.read(pendingRegistrationListControllerProvider('s1'));

  void answerListWith(Result<Page<PendingRegistration>> result) {
    when(
      () => repository.list(
        's1',
        pageNumber: any(named: 'pageNumber'),
        pageSize: any(named: 'pageSize'),
      ),
    ).thenAnswer((_) async => result);
  }

  setUp(() {
    repository = _MockPendingRegistrationRepository();
  });

  test('GivenAScope_WhenLoaded_ThenTheFirstPageIsShown', () async {
    // Given
    answerListWith(Success<Page<PendingRegistration>>(_page()));
    final controller = controllerUnderTest();

    // When
    await controller.load();

    // Then
    final state = currentState() as PendingRegistrationListLoaded;
    expect(state.page.items, <PendingRegistration>[_ada]);
    verify(() => repository.list('s1', pageNumber: 1)).called(1);
  });

  test('GivenARefusedList_WhenLoaded_ThenTheFailureIsKept', () async {
    // Given
    answerListWith(
      const FailureResult<Page<PendingRegistration>>(
        Failure(kind: FailureKind.notFound, errors: <String>['Not found.']),
      ),
    );
    final controller = controllerUnderTest();

    // When
    await controller.load();

    // Then
    final state = currentState() as PendingRegistrationListFailed;
    expect(state.failure.kind, FailureKind.notFound);
  });

  test('GivenALoadedList_WhenAnotherPageIsRequested_ThenItIsFetched', () async {
    // Given
    answerListWith(Success<Page<PendingRegistration>>(_page(totalPages: 3)));
    final controller = controllerUnderTest();
    await controller.load();

    // When
    await controller.goToPage(2);

    // Then
    expect(currentState().pageNumber, 2);
    verify(() => repository.list('s1', pageNumber: 2)).called(1);
  });

  test('GivenTheLastRowOfTheLastPage_WhenDiscarded_ThenThePreviousPageShowsWithTheNotice', () async {
    // Given
    var calls = 0;
    when(
      () => repository.list(
        's1',
        pageNumber: any(named: 'pageNumber'),
        pageSize: any(named: 'pageSize'),
      ),
    ).thenAnswer((invocation) async {
      calls++;
      final number = invocation.namedArguments[#pageNumber] as int;

      return Success<Page<PendingRegistration>>(
        calls <= 1
            ? _page(pageNumber: number, totalPages: 2)
            : _page(
                items: const <PendingRegistration>[],
                pageNumber: number,
                totalPages: 1,
              ),
      );
    });
    when(() => repository.discard('s1', 'r1'))
        .thenAnswer((_) async => const Success<void>(null));
    final controller = controllerUnderTest();
    await controller.goToPage(2);

    // When
    await controller.discard(_ada);

    // Then — the notice outlives the fetch that fell back a page.
    final state = currentState() as PendingRegistrationListLoaded;
    expect(state.pageNumber, 1);
    expect(state.notice, 'Registration discarded.');
    expect(state.busy, isFalse);
  });

  test(
    'GivenARegistration_WhenDiscarded_ThenTheListReloadsWithANotice',
    () async {
      // Given
      answerListWith(Success<Page<PendingRegistration>>(_page()));
      when(() => repository.discard('s1', 'r1'))
          .thenAnswer((_) async => const Success<void>(null));
      final controller = controllerUnderTest();
      await controller.load();

      // When
      await controller.discard(_ada);

      // Then
      final state = currentState() as PendingRegistrationListLoaded;
      expect(state.notice, 'Registration discarded.');
      verify(
        () => repository.list(
          's1',
          pageNumber: any(named: 'pageNumber'),
          pageSize: any(named: 'pageSize'),
        ),
      ).called(2);
    },
  );

  test(
    'GivenADiscardInFlight_WhenObserved_ThenTheListIsBusyUntilItReloads',
    () async {
      // Given
      answerListWith(Success<Page<PendingRegistration>>(_page()));
      final deleted = Completer<Result<void>>();
      when(() => repository.discard('s1', 'r1'))
          .thenAnswer((_) => deleted.future);
      final controller = controllerUnderTest();
      await controller.load();
      final reloaded = Completer<Result<Page<PendingRegistration>>>();
      when(
        () => repository.list(
          's1',
          pageNumber: any(named: 'pageNumber'),
          pageSize: any(named: 'pageSize'),
        ),
      ).thenAnswer((_) => reloaded.future);
      bool busy() => (currentState() as PendingRegistrationListLoaded).busy;

      // When
      final discarding = controller.discard(_ada);

      // Then — busy while the DELETE is out, through the reload after it, and
      // idle once the list is back.
      expect(busy(), isTrue);
      deleted.complete(const Success<void>(null));
      await pumpEventQueue();
      expect(busy(), isTrue);
      reloaded.complete(Success<Page<PendingRegistration>>(_page()));
      await discarding;
      expect(busy(), isFalse);
    },
  );

  test(
    'GivenADiscardInFlight_WhenAnotherIsAsked_ThenItIsRefusedAndBusyHolds',
    () async {
      // Given
      answerListWith(Success<Page<PendingRegistration>>(_page()));
      final deleted = Completer<Result<void>>();
      when(() => repository.discard('s1', any()))
          .thenAnswer((_) => deleted.future);
      final controller = controllerUnderTest();
      await controller.load();
      final reloaded = Completer<Result<Page<PendingRegistration>>>();
      when(
        () => repository.list(
          's1',
          pageNumber: any(named: 'pageNumber'),
          pageSize: any(named: 'pageSize'),
        ),
      ).thenAnswer((_) => reloaded.future);
      bool busy() => (currentState() as PendingRegistrationListLoaded).busy;
      final first = controller.discard(_ada);

      // When — neither is awaited first, so a call that went out shows.
      final second = controller.discard(
        const PendingRegistration(
          id: 'r2',
          name: 'Grace Hopper',
          email: 'grace@example.com',
          attemptsLeft: 3,
          expired: false,
        ),
      );
      final paged = controller.goToPage(2);
      await pumpEventQueue();

      // Then — only the first DELETE went out, and nothing else was fetched.
      verify(() => repository.discard('s1', 'r1')).called(1);
      verifyNever(() => repository.discard('s1', 'r2'));
      expect(busy(), isTrue);
      deleted.complete(const Success<void>(null));
      await pumpEventQueue();
      expect(busy(), isTrue);
      reloaded.complete(Success<Page<PendingRegistration>>(_page()));
      await Future.wait(<Future<void>>[first, second, paged]);
      expect(busy(), isFalse);
      verifyNever(() => repository.list('s1', pageNumber: 2));
      expect(
        (currentState() as PendingRegistrationListLoaded).notice,
        'Registration discarded.',
      );
    },
  );

  test('GivenADiscardInFlight_WhenTheScreenReloads_ThenNothingIsSentAndTheNoticeShows', () async {
    // Given
    answerListWith(Success<Page<PendingRegistration>>(_page()));
    final deleted = Completer<Result<void>>();
    when(() => repository.discard('s1', 'r1'))
        .thenAnswer((_) => deleted.future);
    final controller = controllerUnderTest();
    await controller.load();
    clearInteractions(repository);
    bool busy() => (currentState() as PendingRegistrationListLoaded).busy;
    final discarding = controller.discard(_ada);

    // When — the screen is opened again, which loads on every visit.
    final reloading = controller.load();
    await pumpEventQueue();

    // Then — nothing is fetched while the DELETE is out.
    verifyNever(
      () => repository.list(
        's1',
        pageNumber: any(named: 'pageNumber'),
        pageSize: any(named: 'pageSize'),
      ),
    );
    expect(busy(), isTrue);
    deleted.complete(const Success<void>(null));
    await Future.wait(<Future<void>>[discarding, reloading]);
    final state = currentState() as PendingRegistrationListLoaded;
    expect(state.busy, isFalse);
    expect(state.notice, 'Registration discarded.');
  });

  test('GivenARefusedDiscard_WhenItEnds_ThenTheListIsNoLongerBusy', () async {
    // Given
    answerListWith(Success<Page<PendingRegistration>>(_page()));
    when(() => repository.discard('s1', 'r1')).thenAnswer(
      (_) async => const FailureResult<void>(
        Failure(kind: FailureKind.network, errors: <String>[]),
      ),
    );
    final controller = controllerUnderTest();
    await controller.load();

    // When
    await controller.discard(_ada);

    // Then
    final state = currentState() as PendingRegistrationListLoaded;
    expect(state.busy, isFalse);
    expect(state.discardFailure, isNotNull);
  });

  test(
    'GivenAnAlreadyGoneRegistration_WhenDiscarded_ThenTheListReloadsAndSaysSo',
    () async {
      // Given — AF-35d
      answerListWith(Success<Page<PendingRegistration>>(_page()));
      when(() => repository.discard('s1', 'r1')).thenAnswer(
        (_) async => const FailureResult<void>(
          Failure(
            kind: FailureKind.notFound,
            errors: <String>['Pending registration not found.'],
          ),
        ),
      );
      final controller = controllerUnderTest();
      await controller.load();

      // When
      await controller.discard(_ada);

      // Then
      final state = currentState() as PendingRegistrationListLoaded;
      expect(state.notice, 'That registration no longer exists.');
      expect(state.discardFailure, isNull);
    },
  );

  test(
    'GivenARefusedDiscard_WhenDiscarded_ThenTheFailureIsShownAndTheListKept',
    () async {
      // Given
      answerListWith(Success<Page<PendingRegistration>>(_page()));
      when(() => repository.discard('s1', 'r1')).thenAnswer(
        (_) async => const FailureResult<void>(
          Failure(
            kind: FailureKind.forbidden,
            errors: <String>['You are not an owner of the target scope.'],
          ),
        ),
      );
      final controller = controllerUnderTest();
      await controller.load();

      // When
      await controller.discard(_ada);

      // Then
      final state = currentState() as PendingRegistrationListLoaded;
      expect(state.discardFailure!.errors, <String>[
        'You are not an owner of the target scope.',
      ]);
      expect(state.page.items, isNotEmpty);
    },
  );
}
