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

import '../../../support/late_answer.dart';

class _MockGoogleUserRepository extends Mock implements GoogleUserRepository {}

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
}
