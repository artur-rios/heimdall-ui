import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/core/network/envelope.dart';
import 'package:heimdall_ui/core/result/result.dart';
import 'package:heimdall_ui/features/scope_invitations/domain/scope_invitation.dart';
import 'package:heimdall_ui/features/scope_invitations/domain/scope_invitation_repository.dart';
import 'package:heimdall_ui/features/scope_invitations/presentation/scope_invitations_controller.dart';
import 'package:heimdall_ui/features/scopes/presentation/scope_list_controller.dart';
import 'package:mocktail/mocktail.dart';

import '../../../support/late_answer.dart';

class _MockScopeInvitationRepository extends Mock
    implements ScopeInvitationRepository {}

const _initech = ScopeInvitation(
  id: 'invitation-1',
  scopeId: 'scope-9',
  scopeName: 'Initech',
  invitedByName: 'Ada',
);

const _notOpen = 'The invitation was not found or is no longer open.';

Page<ScopeInvitation> _page(List<ScopeInvitation> items) =>
    Page<ScopeInvitation>(
      items: items,
      pageNumber: 1,
      pageSize: 50,
      totalItems: items.length,
      totalPages: 1,
    );

/// A scope list that counts how often it is built.
class _CountingScopeList extends ScopeListController {
  static int builds = 0;

  @override
  ScopeListState build() {
    builds++;

    return super.build();
  }
}

void main() {
  late _MockScopeInvitationRepository repository;
  late ProviderContainer container;

  ScopeInvitationsController controllerUnderTest() {
    _CountingScopeList.builds = 0;
    container = ProviderContainer(
      overrides: <Override>[
        scopeListControllerProvider.overrideWith(_CountingScopeList.new),
        scopeInvitationRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    return container.read(scopeInvitationsControllerProvider.notifier);
  }

  ScopeInvitationsState currentState() =>
      container.read(scopeInvitationsControllerProvider);

  void answerMineWith(Result<Page<ScopeInvitation>> result) {
    when(
      () => repository.listMine(
        pageNumber: any(named: 'pageNumber'),
        pageSize: any(named: 'pageSize'),
      ),
    ).thenAnswer((_) async => result);
  }

  setUp(() {
    repository = _MockScopeInvitationRepository();
    answerMineWith(
      Success<Page<ScopeInvitation>>(_page(const <ScopeInvitation>[_initech])),
    );
  });

  test('GivenOpenInvitations_WhenLoaded_ThenTheyAreListed', () async {
    // Given
    final controller = controllerUnderTest();

    // When
    await controller.load();

    // Then
    final state = currentState() as ScopeInvitationsLoaded;
    expect(state.invitations.single.scopeName, 'Initech');
    expect(state.isVisible, isTrue);
  });

  test('GivenNoInvitations_WhenLoaded_ThenNothingIsVisible', () async {
    // Given — AF-39a
    answerMineWith(
      Success<Page<ScopeInvitation>>(_page(const <ScopeInvitation>[])),
    );
    final controller = controllerUnderTest();

    // When
    await controller.load();

    // Then
    expect((currentState() as ScopeInvitationsLoaded).isVisible, isFalse);
  });

  test('GivenAFailedListing_WhenLoaded_ThenTheyAreUnavailable', () async {
    // Given — AF-39e
    answerMineWith(
      const FailureResult<Page<ScopeInvitation>>(
        Failure(kind: FailureKind.server, errors: <String>['Unreadable']),
      ),
    );
    final controller = controllerUnderTest();

    // When
    await controller.load();

    // Then
    expect(currentState(), isA<ScopeInvitationsUnavailable>());
  });

  test('GivenAnInvitation_WhenAccepted_ThenItIsSentRereadAndNoticed', () async {
    // Given
    when(() => repository.accept(any()))
        .thenAnswer((_) async => const Success<void>(null));
    final controller = controllerUnderTest();
    await controller.load();
    answerMineWith(
      Success<Page<ScopeInvitation>>(_page(const <ScopeInvitation>[])),
    );

    // When
    final taken = await controller.accept(_initech);

    // Then
    expect(taken, isTrue);
    verify(() => repository.accept('invitation-1')).called(1);
    final state = currentState() as ScopeInvitationsLoaded;
    expect(state.invitations, isEmpty);
    expect(state.notice, 'Invitation accepted. You now co-own Initech.');
    expect(state.isVisible, isTrue);
  });

  test('GivenAnEndedInvitation_WhenAccepted_ThenTheListIsRereadAndTheApiMessageShown', () async {
    // Given — AF-39c: withdrawn, expired or already answered
    when(() => repository.accept(any())).thenAnswer(
      (_) async => const FailureResult<void>(
        Failure(kind: FailureKind.notFound, errors: <String>[_notOpen]),
      ),
    );
    final controller = controllerUnderTest();
    await controller.load();
    answerMineWith(
      Success<Page<ScopeInvitation>>(_page(const <ScopeInvitation>[])),
    );

    // When
    final taken = await controller.accept(_initech);

    // Then
    expect(taken, isFalse);
    final state = currentState() as ScopeInvitationsLoaded;
    expect(state.invitations, isEmpty);
    expect(state.failure?.errors, <String>[_notOpen]);
    expect(state.notice, isNull);
  });

  test(
    'GivenAServerFailure_WhenDeclined_ThenTheListIsKeptWithTheFailure',
    () async {
      // Given — AF-39d
      when(() => repository.decline(any())).thenAnswer(
        (_) async => const FailureResult<void>(
          Failure(
            kind: FailureKind.server,
            errors: <String>['Try again later.'],
          ),
        ),
      );
      final controller = controllerUnderTest();
      await controller.load();

      // When
      final taken = await controller.decline(_initech);

      // Then
      expect(taken, isFalse);
      final state = currentState() as ScopeInvitationsLoaded;
      expect(state.invitations.single.id, 'invitation-1');
      expect(state.failure?.errors, <String>['Try again later.']);
      verify(
        () => repository.listMine(
          pageNumber: any(named: 'pageNumber'),
          pageSize: any(named: 'pageSize'),
        ),
      ).called(1);
    },
  );

  test('GivenAnInvitation_WhenDeclined_ThenTheNoticeSaysSo', () async {
    // Given
    when(() => repository.decline(any()))
        .thenAnswer((_) async => const Success<void>(null));
    final controller = controllerUnderTest();
    await controller.load();

    // When
    await controller.decline(_initech);

    // Then
    verify(() => repository.decline('invitation-1')).called(1);
    expect(
      (currentState() as ScopeInvitationsLoaded).notice,
      'Invitation declined.',
    );
  });

  // A sign-out resets the invitations while their read is in flight, and the
  // late answer must not land in the reset state.
  test(
    'GivenALoadInFlight_WhenTheSessionResets_ThenTheAnswerIsDropped',
    () async {
      // Given
      final answer = Completer<Result<Page<ScopeInvitation>>>();
      when(
        () => repository.listMine(
          pageNumber: any(named: 'pageNumber'),
          pageSize: any(named: 'pageSize'),
        ),
      ).thenAnswer((_) => answer.future);
      final controller = controllerUnderTest();

      // When
      await answerAfterReset(
        container,
        scopeInvitationsControllerProvider,
        reset: scopeInvitationsControllerProvider,
        start: controller.load,
        answer: () => answer.complete(
          Success<Page<ScopeInvitation>>(
            _page(const <ScopeInvitation>[_initech]),
          ),
        ),
      );

      // Then
      expect(currentState(), isA<ScopeInvitationsLoading>());
    },
  );

  Future<int> scopeListBuildsAfter(
    Future<bool> Function(ScopeInvitationsController) answer,
  ) async {
    final controller = controllerUnderTest();
    // A listener keeps the list alive, so an invalidation rebuilds it at once.
    container.listen(scopeListControllerProvider, (_, _) {});
    await controller.load();
    final before = _CountingScopeList.builds;

    await answer(controller);
    // The rebuild of a listened provider is scheduled, not immediate.
    await Future<void>.delayed(Duration.zero);

    return _CountingScopeList.builds - before;
  }

  test('GivenAnInvitation_WhenAccepted_ThenTheScopeListIsRebuilt', () async {
    // Given
    when(() => repository.accept(any()))
        .thenAnswer((_) async => const Success<void>(null));

    // When
    final rebuilds = await scopeListBuildsAfter((c) => c.accept(_initech));

    // Then
    expect(rebuilds, 1);
  });

  test('GivenAnInvitation_WhenDeclined_ThenTheScopeListIsLeftAlone', () async {
    // Given
    when(() => repository.decline(any()))
        .thenAnswer((_) async => const Success<void>(null));

    // When
    final rebuilds = await scopeListBuildsAfter((c) => c.decline(_initech));

    // Then
    expect(rebuilds, 0);
  });

  test(
    'GivenAnEndedInvitation_WhenAccepted_ThenTheScopeListIsLeftAlone',
    () async {
      // Given
      when(() => repository.accept(any())).thenAnswer(
        (_) async => const FailureResult<void>(
          Failure(kind: FailureKind.notFound, errors: <String>[_notOpen]),
        ),
      );

      // When
      final rebuilds = await scopeListBuildsAfter((c) => c.accept(_initech));

      // Then
      expect(rebuilds, 0);
    },
  );

  test(
    'GivenAServerFailure_WhenAccepted_ThenTheScopeListIsLeftAlone',
    () async {
      // Given
      when(() => repository.accept(any())).thenAnswer(
        (_) async => const FailureResult<void>(
          Failure(
            kind: FailureKind.server,
            errors: <String>['Try again later.'],
          ),
        ),
      );

      // When
      final rebuilds = await scopeListBuildsAfter((c) => c.accept(_initech));

      // Then
      expect(rebuilds, 0);
    },
  );

  test(
    'GivenARepositoryThatThrows_WhenAccepted_ThenTheCardIsNotLeftBusy',
    () async {
      // Given
      when(() => repository.accept(any()))
          .thenThrow(const FormatException('x'));
      final controller = controllerUnderTest();
      await controller.load();

      // When
      final taken = await controller.accept(_initech);

      // Then
      expect(taken, isFalse);
      final state = currentState() as ScopeInvitationsLoaded;
      expect(state.busy, isFalse);
      expect(state.failure, isNotNull);
      expect(state.invitations.single.id, 'invitation-1');
    },
  );

  test(
    'GivenAnAnswerPending_WhenAcceptedAgain_ThenNoSecondRequestIsSent',
    () async {
      // Given
      final answer = Completer<Result<void>>();
      when(() => repository.accept(any())).thenAnswer((_) => answer.future);
      final controller = controllerUnderTest();
      await controller.load();
      final first = controller.accept(_initech);

      // When
      final second = await controller.accept(_initech);
      answer.complete(const Success<void>(null));
      await first;

      // Then
      expect(second, isFalse);
      verify(() => repository.accept('invitation-1')).called(1);
    },
  );
}
