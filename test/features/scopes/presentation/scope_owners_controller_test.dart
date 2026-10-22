import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/core/network/envelope.dart';
import 'package:heimdall_ui/core/result/result.dart';
import 'package:heimdall_ui/features/auth/domain/session.dart';
import 'package:heimdall_ui/features/persons/domain/person.dart';
import 'package:heimdall_ui/features/persons/domain/person_repository.dart';
import 'package:heimdall_ui/features/profile/presentation/profile_controller.dart';
import 'package:heimdall_ui/features/scope_invitations/domain/scope_invitation.dart';
import 'package:heimdall_ui/features/scope_invitations/domain/scope_invitation_repository.dart';
import 'package:heimdall_ui/features/scopes/presentation/scope_owners_controller.dart';
import 'package:mocktail/mocktail.dart';

import '../../../support/home_stale_spy.dart';
import '../../../support/late_answer.dart';

class _MockPersonRepository extends Mock implements PersonRepository {}

class _MockScopeInvitationRepository extends Mock
    implements ScopeInvitationRepository {}

const _hedyInvited = OwnerInvitation(
  id: 'invitation-1',
  inviteeId: 'person-7',
  inviteeName: 'Hedy',
  inviteeEmail: 'hedy@example.com',
  invitedByName: 'Ada',
);

Page<OwnerInvitation> _invitations(List<OwnerInvitation> items) =>
    Page<OwnerInvitation>(
      items: items,
      pageNumber: 1,
      pageSize: 50,
      totalItems: items.length,
      totalPages: 1,
    );

const _ada = Person(
  id: 'person-1',
  name: 'Ada',
  email: 'ada@example.com',
  role: Role.scopeAdmin,
);

const _grace = Person(
  id: 'person-2',
  name: 'Grace',
  email: 'grace@example.com',
  role: Role.scopeAdmin,
);

const _user = Person(
  id: 'person-3',
  name: 'Alan',
  email: 'alan@example.com',
  role: Role.user,
);

Page<Person> _page(List<Person> items) => Page<Person>(
  items: items,
  pageNumber: 1,
  pageSize: 20,
  totalItems: items.length,
  totalPages: 1,
);

void main() {
  late _MockPersonRepository repository;
  late _MockScopeInvitationRepository invitations;
  late ProviderContainer container;

  ScopeOwnersController controllerUnderTest() {
    container = ProviderContainer(
      overrides: <Override>[
        staleSpyOverride(),
        personRepositoryProvider.overrideWithValue(repository),
        scopeInvitationRepositoryProvider.overrideWithValue(invitations),
      ],
    );
    addTearDown(container.dispose);

    return container.read(scopeOwnersControllerProvider('scope-1').notifier);
  }

  ScopeOwnersState currentState() =>
      container.read(scopeOwnersControllerProvider('scope-1'));

  void answerOwnersWith(Result<Page<Person>> result) {
    when(
      () => repository.listScopeOwners(
        scopeId: any(named: 'scopeId'),
        name: any(named: 'name'),
        email: any(named: 'email'),
        includeDeleted: any(named: 'includeDeleted'),
        pageNumber: any(named: 'pageNumber'),
        pageSize: any(named: 'pageSize'),
      ),
    ).thenAnswer((_) async => result);
  }

  void answerInvitationsWith(Result<Page<OwnerInvitation>> result) {
    when(
      () => invitations.listForScope(
        any(),
        pageNumber: any(named: 'pageNumber'),
        pageSize: any(named: 'pageSize'),
      ),
    ).thenAnswer((_) async => result);
  }

  void answerUsersWith(Result<Page<Person>> result) {
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

  setUp(() {
    repository = _MockPersonRepository();
    invitations = _MockScopeInvitationRepository();
    answerInvitationsWith(
      Success<Page<OwnerInvitation>>(_invitations(const <OwnerInvitation>[])),
    );
    answerOwnersWith(Success<Page<Person>>(_page(<Person>[_ada, _grace])));
    answerUsersWith(Success<Page<Person>>(_page(<Person>[_user])));
  });

  test('GivenAScope_WhenLoaded_ThenItsOwnersAreShown', () async {
    // Given
    final controller = controllerUnderTest();

    // When
    await controller.load();

    // Then
    final state = currentState() as ScopeOwnersLoaded;
    expect(state.owners.map((owner) => owner.name), <String>['Ada', 'Grace']);
  });

  test('GivenAFailedOwnerListing_WhenLoaded_ThenStateIsUnavailable', () async {
    // Given
    answerOwnersWith(
      const FailureResult<Page<Person>>(
        Failure(kind: FailureKind.network, errors: <String>[]),
      ),
    );
    final controller = controllerUnderTest();

    // When
    await controller.load();

    // Then
    expect(currentState(), isA<ScopeOwnersUnavailable>());
  });

  test('GivenAScopeAdminId_WhenAdded_ThenTheApiIsAsked', () async {
    // Given
    when(
      () => repository.addScopeOwner(
        scopeId: any(named: 'scopeId'),
        personId: any(named: 'personId'),
      ),
    ).thenAnswer(
      (_) async => const Success<AddOwnerOutcome>(AddOwnerOutcome.added),
    );
    final controller = controllerUnderTest();
    await controller.load();

    // When
    await controller.addOwner('person-9');

    // Then
    verify(
      () => repository.addScopeOwner(scopeId: 'scope-1', personId: 'person-9'),
    ).called(1);
  });

  // AF-14b — the person is not a Scope Admin.
  test('GivenARejectedOwner_WhenAdded_ThenApiErrorsAreKept', () async {
    // Given
    when(
      () => repository.addScopeOwner(
        scopeId: any(named: 'scopeId'),
        personId: any(named: 'personId'),
      ),
    ).thenAnswer(
      (_) async => const FailureResult<AddOwnerOutcome>(
        Failure(
          kind: FailureKind.validation,
          errors: <String>['person-9 is not a Scope Admin.'],
        ),
      ),
    );
    final controller = controllerUnderTest();
    await controller.load();

    // When
    await controller.addOwner('person-9');

    // Then
    final state = currentState() as ScopeOwnersLoaded;
    expect(state.failure?.errors, <String>['person-9 is not a Scope Admin.']);

    // And whether Home was told
    expect(staleMarksOf(container), 0);
  });

  // #159 — the last-owner rule counts every owner the API reports, not the
  // ones on the page: the second page of 21 owners holds a single row.
  test(
    'GivenOwnersOnSeveralPages_WhenALonePageLoaded_ThenRemovalIsOffered',
    () async {
      // Given
      answerOwnersWith(
        const Success<Page<Person>>(
          Page<Person>(
            items: <Person>[_ada],
            pageNumber: 2,
            pageSize: 20,
            totalItems: 21,
            totalPages: 2,
          ),
        ),
      );
      final controller = controllerUnderTest();

      // When
      await controller.load();

      // Then
      final state = currentState() as ScopeOwnersLoaded;
      expect(state.owners, hasLength(1));
      expect(state.canRemove, isTrue);
    },
  );

  test(
    'GivenAnOwnersPage_WhenAnotherIsAsked_ThenItReplacesTheShownOne',
    () async {
      // Given
      final controller = controllerUnderTest();
      await controller.load();
      answerOwnersWith(
        const Success<Page<Person>>(
          Page<Person>(
            items: <Person>[_grace],
            pageNumber: 2,
            pageSize: 20,
            totalItems: 21,
            totalPages: 2,
          ),
        ),
      );

      // When
      await controller.goToOwnersPage(2);

      // Then
      final state = currentState() as ScopeOwnersLoaded;
      expect(state.owners.single.name, 'Grace');
      expect(state.busy, isFalse);
      verify(
        () => repository.listScopeOwners(scopeId: 'scope-1', pageNumber: 2),
      ).called(1);
    },
  );

  test(
    'GivenAFailedPage_WhenAskedFor_ThenTheShownPageStaysWithTheFailure',
    () async {
      // Given
      final controller = controllerUnderTest();
      await controller.load();
      answerOwnersWith(
        const FailureResult<Page<Person>>(
          Failure(kind: FailureKind.network, errors: <String>[]),
        ),
      );

      // When
      await controller.goToOwnersPage(2);

      // Then
      final state = currentState() as ScopeOwnersLoaded;
      expect(state.owners, hasLength(2));
      expect(state.failure?.kind, FailureKind.network);
      expect(state.busy, isFalse);
    },
  );

  test('GivenOwnersStillLoading_WhenAPageIsAsked_ThenNothingIsRead', () async {
    // Given
    final controller = controllerUnderTest();

    // When
    await controller.goToOwnersPage(2);

    // Then
    verifyNever(
      () => repository.listScopeOwners(
        scopeId: any(named: 'scopeId'),
        pageNumber: any(named: 'pageNumber'),
      ),
    );
  });

  // The last owner of the last page was removed: the page that held them no
  // longer exists, and an empty one with no pager to leave by is no answer.
  test(
    'GivenTheLastPagesOnlyOwnerRemoved_WhenReloaded_ThenThePreviousPageShows',
    () async {
      // Given
      final controller = controllerUnderTest();
      answerOwnersWith(
        const Success<Page<Person>>(
          Page<Person>(
            items: <Person>[_grace],
            pageNumber: 2,
            pageSize: 20,
            totalItems: 21,
            totalPages: 2,
          ),
        ),
      );
      await controller.load();
      await controller.goToOwnersPage(2);
      when(
        () => repository.listScopeOwners(
          scopeId: any(named: 'scopeId'),
          name: any(named: 'name'),
          email: any(named: 'email'),
          includeDeleted: any(named: 'includeDeleted'),
          pageNumber: 2,
          pageSize: any(named: 'pageSize'),
        ),
      ).thenAnswer(
        (_) async => const Success<Page<Person>>(
          Page<Person>(
            items: <Person>[],
            pageNumber: 2,
            pageSize: 20,
            totalItems: 20,
            totalPages: 1,
          ),
        ),
      );
      when(
        () => repository.listScopeOwners(
          scopeId: any(named: 'scopeId'),
          name: any(named: 'name'),
          email: any(named: 'email'),
          includeDeleted: any(named: 'includeDeleted'),
          pageNumber: 1,
          pageSize: any(named: 'pageSize'),
        ),
      ).thenAnswer((_) async => Success<Page<Person>>(_page(<Person>[_ada])));

      when(
        () => repository.removeScopeOwner(
          scopeId: any(named: 'scopeId'),
          personId: any(named: 'personId'),
        ),
      ).thenAnswer((_) async => const Success<void>(null));

      // When
      await controller.removeOwner('person-2');

      // Then
      final state = currentState() as ScopeOwnersLoaded;
      expect(state.owners.single.name, 'Ada');
      expect(state.ownersPage.pageNumber, 1);
    },
  );

  // AF-14a — a scope with one owner is not offered the removal.
  test('GivenASingleOwner_WhenLoaded_ThenRemovalIsNotOffered', () async {
    // Given
    answerOwnersWith(Success<Page<Person>>(_page(<Person>[_ada])));
    final controller = controllerUnderTest();

    // When
    await controller.load();

    // Then
    expect((currentState() as ScopeOwnersLoaded).canRemove, isFalse);
  });

  test('GivenTwoOwners_WhenLoaded_ThenRemovalIsOffered', () async {
    // Given
    final controller = controllerUnderTest();

    // When
    await controller.load();

    // Then
    expect((currentState() as ScopeOwnersLoaded).canRemove, isTrue);
  });

  test('GivenAnOwner_WhenRemoved_ThenTheApiIsAsked', () async {
    // Given
    when(
      () => repository.removeScopeOwner(
        scopeId: any(named: 'scopeId'),
        personId: any(named: 'personId'),
      ),
    ).thenAnswer((_) async => const Success<void>(null));
    final controller = controllerUnderTest();
    await controller.load();

    // When
    await controller.removeOwner('person-2');

    // Then
    verify(
      () =>
          repository.removeScopeOwner(scopeId: 'scope-1', personId: 'person-2'),
    ).called(1);

    // And whether Home was told
    expect(staleMarksOf(container), 1);
  });

  // AF-14a — the API refuses to leave a scope without an owner.
  test('GivenTheLastOwner_WhenRemovalRefused_ThenApiErrorsAreKept', () async {
    // Given
    when(
      () => repository.removeScopeOwner(
        scopeId: any(named: 'scopeId'),
        personId: any(named: 'personId'),
      ),
    ).thenAnswer(
      (_) async => const FailureResult<void>(
        Failure(
          kind: FailureKind.validation,
          errors: <String>['A scope must keep at least one owner.'],
        ),
      ),
    );
    final controller = controllerUnderTest();
    await controller.load();

    // When
    await controller.removeOwner('person-1');

    // Then
    final state = currentState() as ScopeOwnersLoaded;
    expect(state.failure?.errors, <String>[
      'A scope must keep at least one owner.',
    ]);
  });

  test('GivenAUser_WhenPromoted_ThenTheApiIsAsked', () async {
    // Given
    when(
      () => repository.promoteScopeUser(
        scopeId: any(named: 'scopeId'),
        personId: any(named: 'personId'),
      ),
    ).thenAnswer((_) async => const Success<void>(null));
    final controller = controllerUnderTest();
    await controller.load();

    // When
    await controller.promote('person-3');

    // Then
    verify(
      () =>
          repository.promoteScopeUser(scopeId: 'scope-1', personId: 'person-3'),
    ).called(1);
  });

  // The promoted user is a Scope Admin now, so the list they were offered in
  // must be read again rather than keep them (#159).
  test('GivenAUser_WhenPromoted_ThenTheUserListIsReadAgain', () async {
    // Given
    when(
      () => repository.promoteScopeUser(
        scopeId: any(named: 'scopeId'),
        personId: any(named: 'personId'),
      ),
    ).thenAnswer((_) async => const Success<void>(null));
    final controller = controllerUnderTest();
    await controller.load();

    // When
    await controller.promote('person-3');

    // Then
    verify(
      () => repository.listScopePersons(
        scopeId: 'scope-1',
        name: null,
        email: null,
        pageNumber: 1,
      ),
    ).called(1);
  });

  test('GivenARefusedPromotion_WhenDone_ThenTheUserListIsLeftAlone', () async {
    // Given
    when(
      () => repository.promoteScopeUser(
        scopeId: any(named: 'scopeId'),
        personId: any(named: 'personId'),
      ),
    ).thenAnswer(
      (_) async => const FailureResult<void>(
        Failure(kind: FailureKind.validation, errors: <String>['No.']),
      ),
    );
    final controller = controllerUnderTest();
    await controller.load();

    // When
    final result = await controller.promote('person-3');

    // Then
    expect(result, isA<OwnerCommandRefused>());
    verifyNever(
      () => repository.listScopePersons(
        scopeId: any(named: 'scopeId'),
        name: any(named: 'name'),
        email: any(named: 'email'),
        pageNumber: any(named: 'pageNumber'),
      ),
    );
  });

  test('GivenADraftOwner_WhenCreated_ThenTheValuesAreSent', () async {
    // Given
    when(
      () => repository.createScopeOwner(
        scopeId: any(named: 'scopeId'),
        name: any(named: 'name'),
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async => const Success<Person>(_grace));
    final controller = controllerUnderTest();
    await controller.load();

    // When
    await controller.createOwner(
      name: 'Grace',
      email: 'grace@example.com',
      password: 'secret',
    );

    // Then
    verify(
      () => repository.createScopeOwner(
        scopeId: 'scope-1',
        name: 'Grace',
        email: 'grace@example.com',
        password: 'secret',
      ),
    ).called(1);
  });

  // AF-14d — the API's own rejection of a name, address, or password.
  // The refusal is the dialog's to show, beside what was typed.
  test('GivenARejectedDraft_WhenCreated_ThenApiErrorsAreReturned', () async {
    // Given
    when(
      () => repository.createScopeOwner(
        scopeId: any(named: 'scopeId'),
        name: any(named: 'name'),
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer(
      (_) async => const FailureResult<Person>(
        Failure(
          kind: FailureKind.validation,
          errors: <String>['That email address is already taken.'],
        ),
      ),
    );
    final controller = controllerUnderTest();
    await controller.load();

    // When
    final refusal = await controller.createOwner(
      name: 'Grace',
      email: 'taken@example.com',
      password: 'secret',
    );

    // Then
    expect((refusal as OwnerCommandRefused).failure.errors, <String>[
      'That email address is already taken.',
    ]);
    final state = currentState() as ScopeOwnersLoaded;
    expect(state.failure, isNull);
    expect(state.busy, isFalse);
  });

  // The dialog must not close as if the owner existed when the command was
  // ignored.
  test('GivenOwnersStillLoading_WhenCreated_ThenNothingIsSent', () async {
    // Given
    final controller = controllerUnderTest();

    // When
    final result = await controller.createOwner(
      name: 'Grace',
      email: 'grace@example.com',
      password: 'secret',
    );

    // Then
    expect(result, isA<OwnerCommandNotSent>());
    verifyNever(
      () => repository.createScopeOwner(
        scopeId: any(named: 'scopeId'),
        name: any(named: 'name'),
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    );
  });

  test('GivenACommandInFlight_WhenCreated_ThenNothingIsSent', () async {
    // Given
    final release = Completer<Result<void>>();
    when(
      () => repository.removeScopeOwner(
        scopeId: any(named: 'scopeId'),
        personId: any(named: 'personId'),
      ),
    ).thenAnswer((_) => release.future);
    final controller = controllerUnderTest();
    await controller.load();
    final removing = controller.removeOwner('person-2');

    // When
    final result = await controller.createOwner(
      name: 'Grace',
      email: 'grace@example.com',
      password: 'secret',
    );

    // Then
    expect(result, isA<OwnerCommandNotSent>());
    verifyNever(
      () => repository.createScopeOwner(
        scopeId: any(named: 'scopeId'),
        name: any(named: 'name'),
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    );
    release.complete(const Success<void>(null));
    await removing;
  });

  test('GivenAnAcceptedDraft_WhenCreated_ThenItIsDone', () async {
    // Given
    when(
      () => repository.createScopeOwner(
        scopeId: any(named: 'scopeId'),
        name: any(named: 'name'),
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async => const Success<Person>(_grace));
    final controller = controllerUnderTest();
    await controller.load();

    // When
    final result = await controller.createOwner(
      name: 'Grace',
      email: 'grace@example.com',
      password: 'secret',
    );

    // Then
    expect(result, isA<OwnerCommandDone>());
  });

  // What is on screen after a command is what the API last confirmed, not a
  // guess about what the command did.
  test(
    'GivenASuccessfulCommand_WhenItCompletes_ThenTheOwnersAreReread',
    () async {
      // Given
      when(
        () => repository.addScopeOwner(
          scopeId: any(named: 'scopeId'),
          personId: any(named: 'personId'),
        ),
      ).thenAnswer(
        (_) async => const Success<AddOwnerOutcome>(AddOwnerOutcome.added),
      );
      final controller = controllerUnderTest();
      await controller.load();

      // When
      await controller.addOwner('person-9');

      // Then
      verify(
        () => repository.listScopeOwners(
          scopeId: 'scope-1',
          name: any(named: 'name'),
          email: any(named: 'email'),
          includeDeleted: any(named: 'includeDeleted'),
          pageNumber: any(named: 'pageNumber'),
          pageSize: any(named: 'pageSize'),
        ),
      ).called(2);
    },
  );

  // A sign-out resets the owners while their read is in flight, and the late
  // answer must not land in the reset state.
  test(
    'GivenALoadInFlight_WhenTheSessionResets_ThenTheAnswerIsDropped',
    () async {
      // Given
      final answer = Completer<Result<Page<Person>>>();
      when(
        () => repository.listScopeOwners(
          scopeId: any(named: 'scopeId'),
          name: any(named: 'name'),
          email: any(named: 'email'),
          includeDeleted: any(named: 'includeDeleted'),
          pageNumber: any(named: 'pageNumber'),
          pageSize: any(named: 'pageSize'),
        ),
      ).thenAnswer((_) => answer.future);
      answerUsersWith(Success<Page<Person>>(_page(const <Person>[_user])));
      final controller = controllerUnderTest();

      // When
      await answerAfterReset(
        container,
        scopeOwnersControllerProvider('scope-1'),
        reset: scopeOwnersControllerProvider,
        start: controller.load,
        answer: () =>
            answer.complete(Success<Page<Person>>(_page(const <Person>[_ada]))),
      );

      // Then
      expect(currentState(), isA<ScopeOwnersLoading>());
    },
  );

  void stubAdd(AddOwnerOutcome outcome) {
    when(
      () => repository.addScopeOwner(
        scopeId: any(named: 'scopeId'),
        personId: any(named: 'personId'),
      ),
    ).thenAnswer((_) async => Success<AddOwnerOutcome>(outcome));
  }

  test(
    'GivenAScopeAdminsAdd_WhenTheApiInvites_ThenInvitationSentIsNoticed',
    () async {
      // Given - FR-SC-14: the person is invited, not added
      stubAdd(AddOwnerOutcome.invited);
      final controller = controllerUnderTest();
      await controller.load();
      answerInvitationsWith(
        Success<Page<OwnerInvitation>>(
          _invitations(const <OwnerInvitation>[_hedyInvited]),
        ),
      );

      // When
      await controller.addOwner('person-7');

      // Then
      final state = currentState() as ScopeOwnersLoaded;
      expect(state.notice, 'Invitation sent');
      expect(state.invitations.single.inviteeName, 'Hedy');
      expect(state.owners.map((owner) => owner.name), <String>['Ada', 'Grace']);
    },
  );

  test('GivenASystemAdminsAdd_WhenTheApiAdds_ThenNothingIsNoticed', () async {
    // Given
    stubAdd(AddOwnerOutcome.added);
    final controller = controllerUnderTest();
    await controller.load();

    // When
    await controller.addOwner('person-7');

    // Then
    expect((currentState() as ScopeOwnersLoaded).notice, isNull);
  });

  test('GivenPendingInvitations_WhenLoaded_ThenTheyAreListed', () async {
    // Given
    answerInvitationsWith(
      Success<Page<OwnerInvitation>>(
        _invitations(const <OwnerInvitation>[_hedyInvited]),
      ),
    );
    final controller = controllerUnderTest();

    // When
    await controller.load();

    // Then
    final state = currentState() as ScopeOwnersLoaded;
    expect(state.invitations.single.id, 'invitation-1');
  });

  test(
    'GivenAFailedInvitationListing_WhenLoaded_ThenTheOwnersStillShow',
    () async {
      // Given
      answerInvitationsWith(
        const FailureResult<Page<OwnerInvitation>>(
          Failure(kind: FailureKind.server, errors: <String>['Unreadable']),
        ),
      );
      final controller = controllerUnderTest();

      // When
      await controller.load();

      // Then
      final state = currentState() as ScopeOwnersLoaded;
      expect(state.owners, hasLength(2));
      expect(state.invitations, isEmpty);
    },
  );

  test(
    'GivenAnInvitation_WhenWithdrawn_ThenTheApiIsAskedAndTheListIsReread',
    () async {
      // Given
      answerInvitationsWith(
        Success<Page<OwnerInvitation>>(
          _invitations(const <OwnerInvitation>[_hedyInvited]),
        ),
      );
      when(() => invitations.withdraw(any(), any()))
          .thenAnswer((_) async => const Success<void>(null));
      final controller = controllerUnderTest();
      await controller.load();

      // When
      await controller.withdraw(_hedyInvited);

      // Then
      verify(() => invitations.withdraw('scope-1', 'invitation-1')).called(1);
      verify(
        () => invitations.listForScope(
          'scope-1',
          pageNumber: any(named: 'pageNumber'),
          pageSize: any(named: 'pageSize'),
        ),
      ).called(2);
    },
  );

  test('GivenAnEndedInvitation_WhenWithdrawn_ThenTheListIsRereadAndTheApiMessageShown', () async {
    // Given - another owner withdrew it, or the person answered, earlier
    const notOpen = 'The invitation was not found or is no longer open.';
    answerInvitationsWith(
      Success<Page<OwnerInvitation>>(
        _invitations(const <OwnerInvitation>[_hedyInvited]),
      ),
    );
    when(() => invitations.withdraw(any(), any())).thenAnswer(
      (_) async => const FailureResult<void>(
        Failure(kind: FailureKind.notFound, errors: <String>[notOpen]),
      ),
    );
    final controller = controllerUnderTest();
    await controller.load();
    answerInvitationsWith(
      Success<Page<OwnerInvitation>>(_invitations(const <OwnerInvitation>[])),
    );

    // When
    await controller.withdraw(_hedyInvited);

    // Then
    final state = currentState() as ScopeOwnersLoaded;
    expect(state.invitations, isEmpty);
    expect(state.failure?.errors, <String>[notOpen]);
  });
}
