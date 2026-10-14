import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/core/result/result.dart';
import 'package:heimdall_ui/features/auth/domain/session.dart';
import 'package:heimdall_ui/features/persons/domain/person.dart';
import 'package:heimdall_ui/features/persons/domain/person_repository.dart';
import 'package:heimdall_ui/features/persons/presentation/account_emails_card.dart';
import 'package:heimdall_ui/features/profile/presentation/profile_controller.dart';
import 'package:mocktail/mocktail.dart';

class _MockPersonRepository extends Mock implements PersonRepository {}

const _unverified = Person(
  id: 'person-1',
  name: 'Ada',
  email: 'ada@example.com',
  role: Role.user,
  emailVerified: false,
);

const _verified = Person(
  id: 'person-1',
  name: 'Ada',
  email: 'ada@example.com',
  role: Role.user,
  emailVerified: true,
);

const _cooldown =
    'An email of this kind was sent to this person recently. '
    'Try again in a few minutes.';

void main() {
  late _MockPersonRepository repository;

  Future<void> pump(
    WidgetTester tester,
    Person person, {
    VoidCallback? onVerificationRefused,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          personRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: AccountEmailsCard(
              person: person,
              onVerificationRefused: onVerificationRefused,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
  }

  /// Confirms in the dialog, whose button shares its label with nothing else
  /// worth tapping on the card.
  Future<void> confirmSend(WidgetTester tester) async {
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Send'),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() {
    repository = _MockPersonRepository();
  });

  testWidgets('GivenAnUnverifiedAddress_WhenShown_ThenBothActionsAreOffered', (
    tester,
  ) async {
    // Given / When
    await pump(tester, _unverified);

    // Then
    expect(find.text('Resend verification email'), findsOneWidget);
    expect(find.text('Send password reset'), findsOneWidget);
  });

  testWidgets('GivenAVerifiedAddress_WhenShown_ThenOnlyTheResetIsOffered', (
    tester,
  ) async {
    // Given / When
    await pump(tester, _verified);

    // Then
    expect(find.text('Resend verification email'), findsNothing);
    expect(find.text('Send password reset'), findsOneWidget);
  });

  testWidgets('GivenTheConfirmDialog_WhenShown_ThenItNamesTheAddress', (
    tester,
  ) async {
    // Given
    await pump(tester, _unverified);

    // When
    await tapText(tester, 'Send password reset');

    // Then
    expect(
      find.text('Send a password reset link to ada@example.com?'),
      findsOneWidget,
    );
  });

  testWidgets('GivenTheResetIsConfirmed_WhenSent_ThenItSaysSentToTheAddress', (
    tester,
  ) async {
    // Given
    when(() => repository.sendPasswordReset('person-1'))
        .thenAnswer((_) async => const Success<void>(null));
    await pump(tester, _unverified);

    // When
    await tapText(tester, 'Send password reset');
    await confirmSend(tester);

    // Then
    verify(() => repository.sendPasswordReset('person-1')).called(1);
    expect(find.text('Sent to ada@example.com.'), findsOneWidget);
  });

  testWidgets('GivenTheConfirmationIsCancelled_WhenAsked_ThenNothingIsSent', (
    tester,
  ) async {
    // Given
    await pump(tester, _unverified);

    // When
    await tapText(tester, 'Send password reset');
    await tapText(tester, 'Cancel');

    // Then
    verifyNever(() => repository.sendPasswordReset(any()));
    expect(find.text('Sent to ada@example.com.'), findsNothing);
  });

  testWidgets(
    'GivenA429WithoutRetryAfter_WhenShown_ThenOnlyTheApiMessageAppears',
    (tester) async {
      // Given
      when(() => repository.sendPasswordReset('person-1')).thenAnswer(
        (_) async => const FailureResult<void>(
          Failure(kind: FailureKind.rateLimited, errors: <String>[_cooldown]),
        ),
      );
      await pump(tester, _unverified);

      // When
      await tapText(tester, 'Send password reset');
      await confirmSend(tester);

      // Then
      expect(find.text(_cooldown), findsOneWidget);
      expect(find.textContaining('Try again later'), findsNothing);
    },
  );

  testWidgets(
    'GivenAVerificationRefusedAsVerified_WhenSent_ThenTheScreenIsTold',
    (tester) async {
      // Given
      var refused = 0;
      when(() => repository.sendVerificationEmail('person-1')).thenAnswer(
        (_) async => const FailureResult<void>(
          Failure(
            kind: FailureKind.validation,
            errors: <String>['The email address is already verified.'],
          ),
        ),
      );
      await pump(tester, _unverified, onVerificationRefused: () => refused++);

      // When
      await tapText(tester, 'Resend verification email');
      await confirmSend(tester);

      // Then
      expect(refused, 1);
      expect(
        find.text('The email address is already verified.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('GivenASendInFlight_WhenTheCardIsRemoved_ThenNothingThrows', (
    tester,
  ) async {
    // Given
    final pending = Completer<Result<void>>();
    when(() => repository.sendVerificationEmail('person-1'))
        .thenAnswer((_) => pending.future);
    await pump(tester, _unverified);
    await tapText(tester, 'Resend verification email');
    await confirmSend(tester);

    // When
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          personRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(home: Scaffold(body: SizedBox())),
      ),
    );
    pending.complete(const Success<void>(null));
    await tester.pumpAndSettle();

    // Then
    expect(tester.takeException(), isNull);
  });

  // AF-36f — a transport failure carries the HTTP library's own words.
  testWidgets('GivenATransportFailure_WhenSent_ThenAFixedSentenceIsShown', (
    tester,
  ) async {
    // Given
    when(() => repository.sendPasswordReset('person-1')).thenAnswer(
      (_) async => const FailureResult<void>(
        Failure(
          kind: FailureKind.network,
          errors: <String>[],
          message: 'The connection errored: Connection refused',
        ),
      ),
    );
    await pump(tester, _unverified);

    // When
    await tapText(tester, 'Send password reset');
    await confirmSend(tester);

    // Then
    expect(
      find.text(
        'Could not reach the API. Check your connection and try again.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('The connection errored'), findsNothing);
  });

  testWidgets('GivenASendInFlight_WhenShown_ThenBothActionsAreDisabled', (
    tester,
  ) async {
    // Given
    final pending = Completer<Result<void>>();
    when(() => repository.sendPasswordReset('person-1'))
        .thenAnswer((_) => pending.future);
    await pump(tester, _unverified);

    // When
    await tapText(tester, 'Send password reset');
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Send'),
      ),
    );
    await tester.pump();
    await tester.pump();

    // Then
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Resend verification email'),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Send password reset'),
          )
          .onPressed,
      isNull,
    );
    pending.complete(const Success<void>(null));
    await tester.pumpAndSettle();
  });
}
