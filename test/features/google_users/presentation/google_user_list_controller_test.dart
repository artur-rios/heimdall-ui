import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/core/network/envelope.dart';
import 'package:heimdall_ui/core/result/result.dart';
import 'package:heimdall_ui/features/google_users/domain/google_user.dart';
import 'package:heimdall_ui/features/google_users/domain/google_user_repository.dart';
import 'package:heimdall_ui/features/google_users/presentation/google_user_list_controller.dart';
import 'package:mocktail/mocktail.dart';

import '../../../support/held_answer.dart';
import '../../../support/late_answer.dart';

class _MockGoogleUserRepository extends Mock implements GoogleUserRepository {}

const _grace = GoogleUser(
  id: 'google-1',
  name: 'Grace',
  email: 'grace@example.com',
);

Page<GoogleUser> _page({List<GoogleUser> items = const <GoogleUser>[_grace]}) =>
    Page<GoogleUser>(
      items: items,
      pageNumber: 1,
      pageSize: 20,
      totalItems: items.length,
      totalPages: 1,
    );

void main() {
  late _MockGoogleUserRepository repository;
  late ProviderContainer container;

  GoogleUserListController controllerUnderTest() {
    container = ProviderContainer(
      overrides: <Override>[
        googleUserRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    return container.read(googleUserListControllerProvider('scope-1').notifier);
  }

  GoogleUserListState currentState() =>
      container.read(googleUserListControllerProvider('scope-1'));

  void failWith(Object error) {
    when(
      () => repository.list(
        scopeId: any(named: 'scopeId'),
        name: any(named: 'name'),
        email: any(named: 'email'),
        includeDeleted: any(named: 'includeDeleted'),
        pageNumber: any(named: 'pageNumber'),
        pageSize: any(named: 'pageSize'),
      ),
    ).thenAnswer((_) => Future<Result<Page<GoogleUser>>>.error(error));
  }

  setUp(() {
    repository = _MockGoogleUserRepository();
  });

  test('GivenARepositoryThatThrowsAFormatException_WhenLoaded_ThenTheStateIsFailedAsUnexpected', () async {
    // Given
    failWith(const FormatException('not the shape of a page'));
    final controller = controllerUnderTest();

    // When
    await controller.load();

    // Then
    final state = currentState();
    expect(state, isA<GoogleUserListFailed>());
    final failure = (state as GoogleUserListFailed).failure;
    expect(failure.kind, FailureKind.unknown);
    expect(failure.displayMessage, 'The API returned an unexpected response.');
  });

  // A sign-out resets the listing while its request is in flight, and the late
  // answer must not land in the reset state.
  test(
    'GivenALoadInFlight_WhenTheSessionResets_ThenTheAnswerIsDropped',
    () async {
      // Given
      final answer = Completer<Result<Page<GoogleUser>>>();
      when(
        () => repository.list(
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
        googleUserListControllerProvider('scope-1'),
        reset: googleUserListControllerProvider,
        start: controller.load,
        answer: () => answer.complete(
          const Success<Page<GoogleUser>>(
            Page<GoogleUser>(
              items: <GoogleUser>[],
              pageNumber: 1,
              pageSize: 20,
              totalItems: 0,
              totalPages: 1,
            ),
          ),
        ),
      );

      // Then
      expect(currentState(), isA<GoogleUserListLoading>());
    },
  );

  // #157 — a search queued during a load, then a second change: the request
  // that follows the load carries both.
  test('GivenASearchQueuedDuringALoad_WhenIncludeDeletedIsToggled_ThenTheLastRequestCarriesBoth', () async {
    // Given
    final first = Completer<Result<Page<GoogleUser>>>();
    when(
      () => repository.list(
        scopeId: any(named: 'scopeId'),
        name: any(named: 'name'),
        email: any(named: 'email'),
        includeDeleted: any(named: 'includeDeleted'),
        pageNumber: any(named: 'pageNumber'),
        pageSize: any(named: 'pageSize'),
      ),
    ).thenAnswer(
      heldFirstAnswer(first, () => Success<Page<GoogleUser>>(_page())),
    );
    final controller = controllerUnderTest();
    final loading = controller.load();

    // When
    unawaited(controller.search(name: 'abc'));
    unawaited(controller.setIncludeDeleted(true));
    first.complete(Success<Page<GoogleUser>>(_page()));
    await loading;

    // Then
    verify(
      () => repository.list(
        scopeId: 'scope-1',
        name: 'abc',
        email: '',
        includeDeleted: true,
        pageNumber: 1,
      ),
    ).called(1);
    expect(currentState().query.name, 'abc');
    expect(currentState().query.includeDeleted, isTrue);
  });

  void answerWith(Result<Page<GoogleUser>> result) {
    when(
      () => repository.list(
        scopeId: any(named: 'scopeId'),
        name: any(named: 'name'),
        email: any(named: 'email'),
        includeDeleted: any(named: 'includeDeleted'),
        pageNumber: any(named: 'pageNumber'),
        pageSize: any(named: 'pageSize'),
      ),
    ).thenAnswer((_) async => result);
  }

  test('GivenAScope_WhenLoaded_ThenItsGoogleUsersAreShown', () async {
    // Given
    answerWith(Success<Page<GoogleUser>>(_page()));
    final controller = controllerUnderTest();

    // When
    await controller.load();

    // Then
    verify(
      () => repository.list(
        scopeId: 'scope-1',
        name: '',
        email: '',
        includeDeleted: false,
        pageNumber: 1,
      ),
    ).called(1);
    expect(
      (currentState() as GoogleUserListLoaded).page.items.single.name,
      'Grace',
    );
  });

  // AF-28a — a new search starts at the first page.
  test('GivenPageTwo_WhenSearched_ThenBothFiltersAreSentForPageOne', () async {
    // Given
    answerWith(Success<Page<GoogleUser>>(_page()));
    final controller = controllerUnderTest();
    await controller.goToPage(2);

    // When
    await controller.search(name: 'Grace', email: 'grace@example.com');

    // Then
    verify(
      () => repository.list(
        scopeId: 'scope-1',
        name: 'Grace',
        email: 'grace@example.com',
        includeDeleted: false,
        pageNumber: 1,
      ),
    ).called(1);
    expect(currentState().query.isFiltered, isTrue);
  });

  test('GivenFilters_WhenCleared_ThenTheFullListingIsRead', () async {
    // Given
    answerWith(Success<Page<GoogleUser>>(_page()));
    final controller = controllerUnderTest();
    await controller.setIncludeDeleted(true);

    // When
    await controller.clearFilters();

    // Then
    expect(currentState().query.isFiltered, isFalse);
    verify(
      () => repository.list(
        scopeId: 'scope-1',
        name: '',
        email: '',
        includeDeleted: false,
        pageNumber: 1,
      ),
    ).called(1);
  });

  // AF-28c — a scope this admin does not own.
  test('GivenAForbiddenScope_WhenLoaded_ThenStateIsForbidden', () async {
    // Given
    answerWith(
      const FailureResult<Page<GoogleUser>>(
        Failure(kind: FailureKind.forbidden, errors: <String>[]),
      ),
    );
    final controller = controllerUnderTest();

    // When
    await controller.load();

    // Then
    expect((currentState() as GoogleUserListFailed).isForbidden, isTrue);
  });
}
