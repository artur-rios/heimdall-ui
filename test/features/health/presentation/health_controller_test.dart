import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/core/result/result.dart';
import 'package:heimdall_ui/features/health/domain/health.dart';
import 'package:heimdall_ui/features/health/domain/health_repository.dart';
import 'package:heimdall_ui/features/health/presentation/health_controller.dart';
import 'package:mocktail/mocktail.dart';

import '../../../support/late_answer.dart';

class _MockHealthRepository extends Mock implements HealthRepository {}

void main() {
  late _MockHealthRepository repository;
  late ProviderContainer container;

  HealthController controllerUnderTest() {
    container = ProviderContainer(
      overrides: <Override>[
        healthRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    return container.read(healthControllerProvider.notifier);
  }

  setUp(() {
    repository = _MockHealthRepository();
  });

  // A sign-out resets the screen while its checks are in flight, and the late
  // answers must not land in the reset state.
  test(
    'GivenChecksInFlight_WhenTheSessionResets_ThenTheAnswersAreDropped',
    () async {
      // Given
      final answer = Completer<Result<String>>();
      when(() => repository.ping()).thenAnswer((_) => answer.future);
      when(() => repository.detailed()).thenAnswer(
        (_) async => const Success<Health>(Health(status: 'Healthy')),
      );
      final controller = controllerUnderTest();

      // When
      await answerAfterReset(
        container,
        healthControllerProvider,
        reset: healthControllerProvider,
        start: controller.check,
        answer: () => answer.complete(const Success<String>('Healthy')),
      );

      // Then
      final state = container.read(healthControllerProvider);
      expect(state.liveness, isNull);
      expect(state.detailed, isNull);
      expect(state.checking, isFalse);
    },
  );
}
