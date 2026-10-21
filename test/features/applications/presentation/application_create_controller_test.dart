import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/core/result/result.dart';
import 'package:heimdall_ui/features/applications/domain/application.dart';
import 'package:heimdall_ui/features/applications/domain/application_repository.dart';
import 'package:heimdall_ui/features/applications/presentation/application_create_controller.dart';
import 'package:mocktail/mocktail.dart';

import '../../../support/home_stale_spy.dart';
import '../../../support/late_answer.dart';

class _MockApplicationRepository extends Mock
    implements ApplicationRepository {}

const _billing = Application(id: 'app-1', name: 'Billing', ownerId: 'person-1');

void main() {
  late _MockApplicationRepository repository;
  late ProviderContainer container;

  ApplicationCreateController controllerUnderTest() {
    container = ProviderContainer(
      overrides: <Override>[
        staleSpyOverride(),
        applicationRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    return container.read(
      applicationCreateControllerProvider('scope-1').notifier,
    );
  }

  setUp(() {
    repository = _MockApplicationRepository();
  });

  // A sign-out resets the form while its submission is in flight, and the late
  // answer must not land in the reset state.
  test(
    'GivenACreateInFlight_WhenTheSessionResets_ThenTheAnswerIsDropped',
    () async {
      // Given
      final answer = Completer<Result<Application>>();
      when(
        () => repository.create(
          scopeId: any(named: 'scopeId'),
          name: any(named: 'name'),
          ownerId: any(named: 'ownerId'),
        ),
      ).thenAnswer((_) => answer.future);
      final controller = controllerUnderTest();

      // When
      await answerAfterReset(
        container,
        applicationCreateControllerProvider('scope-1'),
        reset: applicationCreateControllerProvider,
        start: () => controller.create(name: 'Billing', ownerId: 'person-1'),
        answer: () => answer.complete(const Success<Application>(_billing)),
      );

      // Then
      expect(
        container.read(applicationCreateControllerProvider('scope-1')),
        isA<ApplicationCreateEditing>(),
      );
    },
  );

  test('GivenACreatedApplication_WhenCreated_ThenHomeIsMarkedStale', () async {
    // Given
    when(
      () => repository.create(
        scopeId: any(named: 'scopeId'),
        name: any(named: 'name'),
        ownerId: any(named: 'ownerId'),
      ),
    ).thenAnswer((_) async => const Success<Application>(_billing));
    final controller = controllerUnderTest();

    // When
    await controller.create(name: 'Billing', ownerId: 'person-1');

    // Then
    expect(staleMarksOf(container), 1);
  });

  test('GivenARefusedCreate_WhenCreated_ThenHomeIsNotMarkedStale', () async {
    // Given
    when(
      () => repository.create(
        scopeId: any(named: 'scopeId'),
        name: any(named: 'name'),
        ownerId: any(named: 'ownerId'),
      ),
    ).thenAnswer(
      (_) async => const FailureResult<Application>(
        Failure(kind: FailureKind.validation, errors: <String>['Taken']),
      ),
    );
    final controller = controllerUnderTest();

    // When
    await controller.create(name: 'Billing', ownerId: 'person-1');

    // Then
    expect(staleMarksOf(container), 0);
  });
}
