import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/core/result/result.dart';
import 'package:heimdall_ui/features/applications/domain/application_credential.dart';
import 'package:heimdall_ui/features/applications/domain/application_credential_repository.dart';
import 'package:heimdall_ui/features/applications/presentation/credentials_card.dart';
import 'package:heimdall_ui/features/applications/presentation/pending_secret.dart';
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

  testWidgets('GivenADayNextYear_WhenChosen_ThenTheLabelShowsTheYear', (
    tester,
  ) async {
    // Given
    answerListWith(const <ApplicationCredential>[]);
    await pump(tester);
    await openIssueDialog(tester);
    final today = DateUtils.dateOnly(DateTime.now());

    // When — January of next year
    await tester.tap(find.text('Never expires'));
    await tester.pumpAndSettle();
    for (var i = 0; i < 13 - today.month; i++) {
      await tester.tap(find.byTooltip('Next month'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('15'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    // Then
    expect(find.textContaining('${today.year + 1}'), findsOneWidget);
    expect(find.textContaining('Expires on'), findsOneWidget);
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

  testWidgets(
    'GivenTheLimitWasReachedMeanwhile_WhenIssuing_ThenIssueIsDisabled',
    (tester) async {
      // Given
      var listed = 0;
      when(() => repository.list('s1', 'a1')).thenAnswer((_) async {
        listed++;

        return Success(
          listed == 1
              ? const <ApplicationCredential>[]
              : <ApplicationCredential>[_live('c1'), _live('c2')],
        );
      });
      when(
        () => repository.issue('s1', 'a1', expiresAt: any(named: 'expiresAt')),
      ).thenAnswer(
        (_) async => const FailureResult<IssuedCredential>(
          Failure(
            kind: FailureKind.conflict,
            errors: <String>['Two credentials are already live.'],
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
        tester.widget<FilledButton>(issueDialogButton()).onPressed,
        isNull,
      );
    },
  );

  testWidgets('GivenARefusedRevoke_WhenConfirmed_ThenTheMessageShows', (
    tester,
  ) async {
    // Given
    answerListWith(<ApplicationCredential>[_live('c1')]);
    when(() => repository.revoke('s1', 'a1', 'c1')).thenAnswer(
      (_) async => const FailureResult<void>(
        Failure(
          kind: FailureKind.conflict,
          errors: <String>['The credential is already revoked.'],
        ),
      ),
    );
    await pump(tester);

    // When
    await tester.tap(find.text('Revoke'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Revoke'),
      ),
    );
    await tester.pumpAndSettle();

    // Then
    expect(find.text('The credential is already revoked.'), findsOneWidget);
  });

  testWidgets('GivenARefusedList_WhenRetried_ThenTheListShows', (tester) async {
    // Given
    var listed = 0;
    when(() => repository.list('s1', 'a1')).thenAnswer((_) async {
      listed++;

      return listed == 1
          ? const FailureResult<List<ApplicationCredential>>(
              Failure(
                kind: FailureKind.forbidden,
                errors: <String>['Not your application.'],
              ),
            )
          : Success(<ApplicationCredential>[_live('c1')]);
    });
    await pump(tester);
    expect(find.text('Not your application.'), findsOneWidget);

    // When
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    // Then
    expect(find.text('c1'), findsOneWidget);
    expect(find.text('Not your application.'), findsNothing);
  });

  testWidgets('GivenAnExpiredCredential_WhenShown_ThenItIsMarkedExpired', (
    tester,
  ) async {
    // Given
    answerListWith(<ApplicationCredential>[
      ApplicationCredential(
        id: 'c-exp',
        live: false,
        expiresAt: DateTime.utc(2026, 9, 1),
      ),
    ]);

    // When
    await pump(tester);

    // Then
    expect(find.text('Expired'), findsOneWidget);
    expect(find.text('Revoke'), findsOneWidget);
  });

  testWidgets(
    'GivenACredential_WhenItsIdentifierIsCopied_ThenItIsOnTheClipboard',
    (tester) async {
      // Given
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied =
                (call.arguments as Map<Object?, Object?>)['text'] as String?;
          }

          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      answerListWith(<ApplicationCredential>[_live('c1')]);
      await pump(tester);

      // When
      await tester.tap(find.byTooltip('Copy identifier'));
      await tester.pumpAndSettle();

      // Then
      expect(copied, 'c1');
      expect(find.text('Identifier copied.'), findsOneWidget);
    },
  );

  testWidgets(
    'GivenATransportFailure_WhenIssuing_ThenABannerShowsAndTheListReloads',
    (tester) async {
      // Given
      answerListWith(const <ApplicationCredential>[]);
      when(
        () => repository.issue('s1', 'a1', expiresAt: any(named: 'expiresAt')),
      ).thenAnswer(
        (_) async => const FailureResult<IssuedCredential>(
          Failure(
            kind: FailureKind.network,
            errors: <String>[],
            message: 'Connection refused.',
          ),
        ),
      );
      await pump(tester);
      await openIssueDialog(tester);

      // When
      await tester.tap(issueDialogButton());
      await tester.pumpAndSettle();

      // Then
      expect(find.text('Connection refused.'), findsWidgets);
      verify(() => repository.list('s1', 'a1')).called(2);
    },
  );

  testWidgets('GivenANarrowWindowAndALongId_WhenShown_ThenRowsStayCompact', (
    tester,
  ) async {
    // Given
    final id = 'a' * 36;
    answerListWith(<ApplicationCredential>[
      ApplicationCredential(
        id: id,
        live: true,
        createdAt: DateTime.utc(2026, 10, 1, 9),
      ),
      ApplicationCredential(
        id: 'b' * 36,
        live: true,
        createdAt: DateTime.utc(2026, 10, 2, 9),
      ),
    ]);
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          applicationCredentialRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CredentialsCard(scopeId: 's1', applicationId: 'a1'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Then
    expect(tester.takeException(), isNull);
    final row = find.ancestor(
      of: find.text(id),
      matching: find.byType(Padding),
    );
    expect(tester.getSize(row.first).height, lessThan(200));
    await tester.ensureVisible(find.text('Revoke').first);
    await tester.pumpAndSettle();
    expect(find.text('Revoke').first.hitTestable(), findsOneWidget);
  });

  testWidgets('GivenAWideWindowAndALongId_WhenShown_ThenTheIdIsOneLine', (
    tester,
  ) async {
    // Given
    final id = 'a' * 36;
    answerListWith(<ApplicationCredential>[
      ApplicationCredential(id: id, live: true),
    ]);
    await pump(tester);

    // Then
    expect(tester.getSize(find.text(id)).height, lessThan(30));
  });

  testWidgets('GivenARefusedIssue_WhenIssued_ThenThePendingFlagIsClear', (
    tester,
  ) async {
    // Given
    answerListWith(const <ApplicationCredential>[]);
    when(() => repository.issue('s1', 'a1', expiresAt: any(named: 'expiresAt')))
        .thenAnswer(
          (_) async => const FailureResult<IssuedCredential>(
            Failure(kind: FailureKind.validation, errors: <String>['Refused.']),
          ),
        );
    await pump(tester);
    await openIssueDialog(tester);

    // When
    await tester.tap(issueDialogButton());
    await tester.pumpAndSettle();

    // Then
    final container = ProviderScope.containerOf(
      tester.element(find.byType(CredentialsCard)),
    );
    expect(container.read(pendingSecretProvider), isFalse);
  });
}
