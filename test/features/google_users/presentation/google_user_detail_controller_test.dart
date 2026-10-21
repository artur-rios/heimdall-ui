import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/core/result/result.dart';
import 'package:heimdall_ui/features/google_users/domain/google_user.dart';
import 'package:heimdall_ui/features/google_users/domain/google_user_repository.dart';
import 'package:heimdall_ui/features/google_users/presentation/google_user_detail_controller.dart';
import 'package:mocktail/mocktail.dart';

import '../../../support/late_answer.dart';

class _MockGoogleUserRepository extends Mock implements GoogleUserRepository {}

const _grace = GoogleUser(
  id: 'google-1',
  name: 'Grace',
  email: 'grace@example.com',
  scopeId: 'scope-1',
);

const _ref = GoogleUserRef(scopeId: 'scope-1', googleUserId: 'google-1');

void main() {
  late _MockGoogleUserRepository repository;
  late ProviderContainer container;

  GoogleUserDetailController controllerUnderTest() {
    container = ProviderContainer(
      overrides: <Override>[
        googleUserRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    return container.read(googleUserDetailControllerProvider(_ref).notifier);
  }

  setUp(() {
    repository = _MockGoogleUserRepository();
  });

  GoogleUserDetailState currentState() =>
      container.read(googleUserDetailControllerProvider(_ref));

  // A reread must not replace a deletion that is still on its way: its
  // `deleting` guard would be lost and its answer would overwrite the reread.
  test(
    'GivenADeletionInFlight_WhenLoaded_ThenTheDeletionIsLeftAlone',
    () async {
      // Given
      when(
        () => repository.getById(
          scopeId: any(named: 'scopeId'),
          id: any(named: 'id'),
          includeDeleted: any(named: 'includeDeleted'),
        ),
      ).thenAnswer((_) async => const Success<GoogleUser>(_grace));
      final pending = Completer<Result<void>>();
      when(
        () => repository.delete(
          scopeId: any(named: 'scopeId'),
          id: any(named: 'id'),
        ),
      ).thenAnswer((_) => pending.future);
      final controller = controllerUnderTest();
      await controller.load();
      final deleting = controller.delete();

      // When
      await controller.load();

      // Then
      expect((currentState() as GoogleUserDetailLoaded).deleting, isTrue);
      verify(
        () => repository.getById(
          scopeId: any(named: 'scopeId'),
          id: any(named: 'id'),
          includeDeleted: any(named: 'includeDeleted'),
        ),
      ).called(1);
      pending.complete(const Success<void>(null));
      await deleting;
    },
  );

  // A sign-out resets the page while its read is in flight, and the late
  // answer must not land in the reset state.
  test(
    'GivenALoadInFlight_WhenTheSessionResets_ThenTheAnswerIsDropped',
    () async {
      // Given
      final answer = Completer<Result<GoogleUser>>();
      when(
        () => repository.getById(
          scopeId: any(named: 'scopeId'),
          id: any(named: 'id'),
          includeDeleted: any(named: 'includeDeleted'),
        ),
      ).thenAnswer((_) => answer.future);
      final controller = controllerUnderTest();

      // When
      await answerAfterReset(
        container,
        googleUserDetailControllerProvider(_ref),
        reset: googleUserDetailControllerProvider,
        start: controller.load,
        answer: () => answer.complete(const Success<GoogleUser>(_grace)),
      );

      // Then
      expect(
        container.read(googleUserDetailControllerProvider(_ref)),
        isA<GoogleUserDetailLoading>(),
      );
    },
  );
}
