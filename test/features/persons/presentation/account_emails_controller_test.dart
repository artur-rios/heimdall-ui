import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/core/result/result.dart';
import 'package:heimdall_ui/features/persons/domain/person_repository.dart';
import 'package:heimdall_ui/features/persons/presentation/account_emails_controller.dart';
import 'package:heimdall_ui/features/profile/presentation/profile_controller.dart';
import 'package:mocktail/mocktail.dart';

class _MockPersonRepository extends Mock implements PersonRepository {}

void main() {
  late _MockPersonRepository repository;
  late ProviderContainer container;

  AccountEmailsController controllerUnderTest() {
    container = ProviderContainer(
      overrides: <Override>[
        personRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    return container.read(accountEmailsControllerProvider('p1').notifier);
  }

  AccountEmailsState currentState() =>
      container.read(accountEmailsControllerProvider('p1'));

  setUp(() {
    repository = _MockPersonRepository();
  });

  test('GivenAPerson_WhenAResetIsSent_ThenTheStateSaysSent', () async {
    // Given
    when(() => repository.sendPasswordReset('p1'))
        .thenAnswer((_) async => const Success<void>(null));
    final controller = controllerUnderTest();

    // When
    final sent = await controller.send(AccountEmail.passwordReset);

    // Then
    expect(sent, isTrue);
    expect(currentState().sent, AccountEmail.passwordReset);
    expect(currentState().sending, isNull);
    expect(currentState().failure, isNull);
  });

  test('GivenAPerson_WhenAVerificationIsSent_ThenTheStateSaysSent', () async {
    // Given
    when(() => repository.sendVerificationEmail('p1'))
        .thenAnswer((_) async => const Success<void>(null));
    final controller = controllerUnderTest();

    // When
    final sent = await controller.send(AccountEmail.verification);

    // Then
    expect(sent, isTrue);
    expect(currentState().sent, AccountEmail.verification);
  });

  test('GivenARefusal_WhenSent_ThenTheFailureIsKept', () async {
    // Given — AF-36b
    when(() => repository.sendVerificationEmail('p1')).thenAnswer(
      (_) async => const FailureResult<void>(
        Failure(
          kind: FailureKind.conflict,
          errors: <String>[
            "Processing of this person's data is restricted, so no email was sent.",
          ],
        ),
      ),
    );
    final controller = controllerUnderTest();

    // When
    final sent = await controller.send(AccountEmail.verification);

    // Then
    expect(sent, isFalse);
    expect(currentState().failure!.kind, FailureKind.conflict);
    expect(currentState().sent, isNull);
  });

  test('GivenASendInFlight_WhenAskedAgain_ThenTheSecondIsIgnored', () async {
    // Given
    final pending = Completer<Result<void>>();
    when(() => repository.sendPasswordReset('p1'))
        .thenAnswer((_) => pending.future);
    final controller = controllerUnderTest();
    final first = controller.send(AccountEmail.passwordReset);

    // When
    final second = await controller.send(AccountEmail.passwordReset);
    pending.complete(const Success<void>(null));
    await first;

    // Then
    expect(second, isFalse);
    verify(() => repository.sendPasswordReset('p1')).called(1);
  });
}
