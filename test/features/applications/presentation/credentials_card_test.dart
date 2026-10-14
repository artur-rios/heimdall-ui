import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/core/result/result.dart';
import 'package:heimdall_ui/features/applications/domain/application_credential.dart';
import 'package:heimdall_ui/features/applications/domain/application_credential_repository.dart';
import 'package:heimdall_ui/features/applications/presentation/credentials_card.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepository extends Mock implements ApplicationCredentialRepository {}

ApplicationCredential _live(String id) => ApplicationCredential(
  id: id,
  live: true,
  createdAt: DateTime.utc(2026, 10, 1, 9),
);

final ApplicationCredential _revoked = ApplicationCredential(
  id: 'c-old',
  live: false,
  createdAt: DateTime.utc(2026, 9, 1, 9),
  revokedAt: DateTime.utc(2026, 9, 20, 9),
);

void main() {
  late _MockRepository repository;
  late ValueNotifier<bool> showCard;

  void answerListWith(List<ApplicationCredential> credentials) {
    when(() => repository.list('s1', 'a1'))
        .thenAnswer((_) async => Success(credentials));
  }

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          applicationCredentialRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<bool>(
              valueListenable: showCard,
              builder: (context, shown, _) => shown
                  ? const SingleChildScrollView(
                      child: CredentialsCard(
                        scopeId: 's1',
                        applicationId: 'a1',
                      ),
                    )
                  : const Text('elsewhere'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder issueDialogButton() => find.descendant(
    of: find.byType(AlertDialog),
    matching: find.widgetWithText(FilledButton, 'Issue'),
  );

  Future<void> openIssueDialog(WidgetTester tester) async {
    await tester.tap(find.text('Issue credential'));
    await tester.pumpAndSettle();
  }

  setUp(() {
    repository = _MockRepository();
    showCard = ValueNotifier<bool>(true);
    addTearDown(showCard.dispose);
  });

  testWidgets(
    'GivenCredentials_WhenShown_ThenEachShowsItsStatusIssuedExpiresAndLastUsed',
    (tester) async {
      // Given
      answerListWith(<ApplicationCredential>[_live('c1'), _revoked]);

      // When
      await pump(tester);

      // Then
      expect(find.text('c1'), findsOneWidget);
      expect(find.text('Live'), findsOneWidget);
      expect(find.text('Revoked'), findsOneWidget);
      expect(find.textContaining('Expires Never'), findsNWidgets(2));
      expect(find.textContaining('Last used Never'), findsNWidgets(2));
      expect(find.textContaining('Issued '), findsNWidgets(2));
      expect(find.text('Revoke'), findsOneWidget);
    },
  );

  testWidgets('GivenNoCredentials_WhenShown_ThenItSaysSo', (tester) async {
    // Given
    answerListWith(const <ApplicationCredential>[]);

    // When
    await pump(tester);

    // Then
    expect(
      find.text('This application has no credentials yet.'),
      findsOneWidget,
    );
  });

  testWidgets('GivenTwoLive_WhenShown_ThenIssueIsDisabledWithTheHint', (
    tester,
  ) async {
    // Given
    answerListWith(<ApplicationCredential>[_live('c1'), _live('c2')]);

    // When
    await pump(tester);

    // Then
    final button = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('Issue credential'),
        matching: find.byWidgetPredicate((widget) => widget is FilledButton),
      ),
    );
    expect(button.onPressed, isNull);
    expect(
      find.text('Revoke a credential before issuing another.'),
      findsOneWidget,
    );
  });

  testWidgets('GivenAnIssue_WhenCompleted_ThenTheSecretDialogShowsOnce', (
    tester,
  ) async {
    // Given
    answerListWith(<ApplicationCredential>[_live('c1')]);
    when(() => repository.issue('s1', 'a1', expiresAt: any(named: 'expiresAt')))
        .thenAnswer(
          (_) async =>
              const Success(IssuedCredential(id: 'c9', secret: 'hds_once')),
        );
    await pump(tester);

    // When
    await openIssueDialog(tester);
    await tester.tap(issueDialogButton());
    await tester.pumpAndSettle();

    // Then
    expect(find.text('hds_once'), findsOneWidget);
    await tester.tap(find.text("I've stored it"));
    await tester.pumpAndSettle();
    expect(find.text('hds_once'), findsNothing);
    verify(() => repository.issue('s1', 'a1', expiresAt: null)).called(1);
  });

  testWidgets('GivenAChosenDay_WhenIssued_ThenTheExpiryIsTheEndOfThatDay', (
    tester,
  ) async {
    // Given
    answerListWith(const <ApplicationCredential>[]);
    when(() => repository.issue('s1', 'a1', expiresAt: any(named: 'expiresAt')))
        .thenAnswer(
          (_) async =>
              const Success(IssuedCredential(id: 'c9', secret: 'hds_once')),
        );
    await pump(tester);
    await openIssueDialog(tester);

    // When
    await tester.tap(find.text('Never expires'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(issueDialogButton());
    await tester.pumpAndSettle();

    // Then
    final today = DateUtils.dateOnly(DateTime.now());
    verify(
      () => repository.issue('s1', 'a1', expiresAt: credentialExpiryFor(today)),
    ).called(1);
  });

  testWidgets('GivenTheIssueDialog_WhenCancelled_ThenNothingIsSent', (
    tester,
  ) async {
    // Given
    answerListWith(const <ApplicationCredential>[]);
    await pump(tester);
    await openIssueDialog(tester);

    // When
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // Then
    verifyNever(
      () => repository.issue(any(), any(), expiresAt: any(named: 'expiresAt')),
    );
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets(
    'GivenARefusedIssue_WhenIssued_ThenTheDialogStaysWithTheMessage',
    (tester) async {
      // Given
      answerListWith(const <ApplicationCredential>[]);
      when(
        () => repository.issue('s1', 'a1', expiresAt: any(named: 'expiresAt')),
      ).thenAnswer(
        (_) async => const FailureResult<IssuedCredential>(
          Failure(
            kind: FailureKind.validation,
            errors: <String>['The expiry must be in the future.'],
          ),
        ),
      );
      await pump(tester);
      await openIssueDialog(tester);

      // When
      await tester.tap(issueDialogButton());
      await tester.pumpAndSettle();

      // Then
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('The expiry must be in the future.'),
        ),
        findsOneWidget,
      );
      expect(issueDialogButton(), findsOneWidget);
    },
  );

  testWidgets(
    'GivenAnIssueInFlight_WhenBackIsPressed_ThenTheDialogStaysAndTheSecretShows',
    (tester) async {
      // Given
      answerListWith(const <ApplicationCredential>[]);
      final pending = Completer<Result<IssuedCredential>>();
      when(
        () => repository.issue('s1', 'a1', expiresAt: any(named: 'expiresAt')),
      ).thenAnswer((_) => pending.future);
      await pump(tester);
      await openIssueDialog(tester);
      await tester.tap(issueDialogButton());
      await tester.pump();

      // When
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      final navigator = Navigator.of(tester.element(find.byType(AlertDialog)));
      await navigator.maybePop();
      await tester.pumpAndSettle();

      // Then
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Cancel'))
            .onPressed,
        isNull,
      );

      pending.complete(
        const Success(IssuedCredential(id: 'c9', secret: 'hds_held')),
      );
      await tester.pumpAndSettle();
      expect(find.text('hds_held'), findsOneWidget);
    },
  );

  testWidgets(
    'GivenTheCardIsGone_WhenTheIssueCompletes_ThenTheSecretDialogStillShows',
    (tester) async {
      // Given
      answerListWith(const <ApplicationCredential>[]);
      final pending = Completer<Result<IssuedCredential>>();
      when(
        () => repository.issue('s1', 'a1', expiresAt: any(named: 'expiresAt')),
      ).thenAnswer((_) => pending.future);
      await pump(tester);
      await openIssueDialog(tester);
      await tester.tap(issueDialogButton());
      await tester.pump();

      // When
      showCard.value = false;
      await tester.pump();
      pending.complete(
        const Success(IssuedCredential(id: 'c9', secret: 'hds_orphan')),
      );
      await tester.pumpAndSettle();

      // Then
      expect(find.text('elsewhere'), findsOneWidget);
      expect(find.text('hds_orphan'), findsOneWidget);
    },
  );

  testWidgets('GivenARevoke_WhenConfirmed_ThenItIsRevoked', (tester) async {
    // Given
    answerListWith(<ApplicationCredential>[_live('c1')]);
    when(() => repository.revoke('s1', 'a1', 'c1'))
        .thenAnswer((_) async => const Success<void>(null));
    await pump(tester);

    // When
    await tester.tap(find.text('Revoke'));
    await tester.pumpAndSettle();
    expect(find.text('Revoke this credential?'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Revoke'),
      ),
    );
    await tester.pumpAndSettle();

    // Then
    verify(() => repository.revoke('s1', 'a1', 'c1')).called(1);
    expect(find.text('Credential revoked.'), findsOneWidget);
  });

  testWidgets('GivenARevoke_WhenCancelled_ThenNothingIsSent', (tester) async {
    // Given
    answerListWith(<ApplicationCredential>[_live('c1')]);
    await pump(tester);

    // When
    await tester.tap(find.text('Revoke'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // Then
    verifyNever(() => repository.revoke(any(), any(), any()));
  });
}
