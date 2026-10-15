import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/core/network/envelope.dart';
import 'package:heimdall_ui/core/result/result.dart';
import 'package:heimdall_ui/features/audit_log/domain/audit_entry.dart';
import 'package:heimdall_ui/features/audit_log/domain/audit_log_repository.dart';
import 'package:heimdall_ui/features/audit_log/presentation/audit_log_controller.dart';
import 'package:mocktail/mocktail.dart';

import '../../../support/late_answer.dart';

class _MockAuditLogRepository extends Mock implements AuditLogRepository {}

Page<AuditEntry> _page({int totalPages = 1}) => Page<AuditEntry>(
  items: const <AuditEntry>[
    AuditEntry(id: 'a1', action: 'CreateScopeCommand', succeeded: true),
  ],
  pageNumber: 1,
  pageSize: 20,
  totalItems: 1,
  totalPages: totalPages,
);

void main() {
  late _MockAuditLogRepository repository;
  late ProviderContainer container;

  AuditLogController controllerUnderTest() {
    container = ProviderContainer(
      overrides: <Override>[
        auditLogRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    return container.read(auditLogControllerProvider.notifier);
  }

  AuditLogState currentState() => container.read(auditLogControllerProvider);

  Future<Result<Page<AuditEntry>>> anyList() => repository.list(
    filter: any(named: 'filter'),
    pageNumber: any(named: 'pageNumber'),
    pageSize: any(named: 'pageSize'),
  );

  void answerWith(Result<Page<AuditEntry>> result) {
    when(anyList).thenAnswer((_) async => result);
  }

  setUpAll(() {
    registerFallbackValue(const AuditLogFilter());
  });

  setUp(() {
    repository = _MockAuditLogRepository();
  });

  test('GivenAFirstLoad_WhenAnswered_ThenThePageIsLoaded', () async {
    // Given
    answerWith(Success<Page<AuditEntry>>(_page()));
    final controller = controllerUnderTest();

    // When
    await controller.load();

    // Then
    expect(currentState(), isA<AuditLogLoaded>());
  });

  test('GivenAnIdentifierWithSpacesAndCapitals_WhenFiltered_ThenItIsSentNormalised', () async {
    // Given
    answerWith(Success<Page<AuditEntry>>(_page()));
    final controller = controllerUnderTest();
    await controller.load();

    // When
    final accepted = controller.setActor(
      '  6F1C2B9E-0D4A-4C1E-9A3B-2F6D8E7A1B0C ',
    );
    await pumpEventQueue();

    // Then
    expect(accepted, isTrue);
    final sent =
        verify(
              () => repository.list(
                filter: captureAny(named: 'filter'),
                pageNumber: any(named: 'pageNumber'),
                pageSize: any(named: 'pageSize'),
              ),
            ).captured.last
            as AuditLogFilter;
    expect(sent.actorId, '6f1c2b9e-0d4a-4c1e-9a3b-2f6d8e7a1b0c');
  });

  test(
    'GivenTextThatIsNotAnIdentifier_WhenFiltered_ThenNothingIsSent',
    () async {
      // Given
      answerWith(Success<Page<AuditEntry>>(_page()));
      final controller = controllerUnderTest();
      await controller.load();
      clearInteractions(repository);

      // When
      final accepted = controller.setTarget('not-a-guid');
      await pumpEventQueue();

      // Then
      expect(accepted, isFalse);
      verifyNever(anyList);
      expect(currentState().query.filter.targetId, isNull);
    },
  );

  test(
    'GivenAFilterOnPageThree_WhenChanged_ThenTheListGoesBackToPageOne',
    () async {
      // Given
      answerWith(Success<Page<AuditEntry>>(_page(totalPages: 5)));
      final controller = controllerUnderTest();
      await controller.goToPage(3);

      // When
      await controller.setOutcome(false);

      // Then
      expect(currentState().query.pageNumber, 1);
      expect(currentState().query.filter.succeeded, isFalse);
    },
  );

  test(
    'GivenTwoFilterChangesDuringOneLoad_WhenTheLoadEnds_ThenBothAreSentLast',
    () async {
      // Given — the first load is held open
      final firstAnswer = Completer<Result<Page<AuditEntry>>>();
      var calls = 0;
      when(anyList).thenAnswer((_) {
        calls++;

        return calls == 1
            ? firstAnswer.future
            : Future<Result<Page<AuditEntry>>>.value(
                Success<Page<AuditEntry>>(_page()),
              );
      });
      final controller = controllerUnderTest();
      final firstLoad = controller.load();

      // When — two changes arrive while it is in flight
      unawaited(controller.setOutcome(false));
      final accepted = controller.setActor(
        '6f1c2b9e-0d4a-4c1e-9a3b-2f6d8e7a1b0c',
      );
      firstAnswer.complete(Success<Page<AuditEntry>>(_page()));
      await firstLoad;
      await pumpEventQueue();

      // Then
      expect(accepted, isTrue);
      final sent =
          verify(
                () => repository.list(
                  filter: captureAny(named: 'filter'),
                  pageNumber: any(named: 'pageNumber'),
                  pageSize: any(named: 'pageSize'),
                ),
              ).captured.last
              as AuditLogFilter;
      expect(sent.succeeded, isFalse);
      expect(sent.actorId, '6f1c2b9e-0d4a-4c1e-9a3b-2f6d8e7a1b0c');
      expect(currentState().query.filter.succeeded, isFalse);
      expect(
        currentState().query.filter.actorId,
        '6f1c2b9e-0d4a-4c1e-9a3b-2f6d8e7a1b0c',
      );
    },
  );

  test(
    'GivenAFilterChangeDuringOneLoad_WhenAPageIsAsked_ThenTheChangeIsKept',
    () async {
      // Given — the first load is held open
      final firstAnswer = Completer<Result<Page<AuditEntry>>>();
      var calls = 0;
      when(anyList).thenAnswer((_) {
        calls++;

        return calls == 1
            ? firstAnswer.future
            : Future<Result<Page<AuditEntry>>>.value(
                Success<Page<AuditEntry>>(_page(totalPages: 5)),
              );
      });
      final controller = controllerUnderTest();
      final firstLoad = controller.load();

      // When
      unawaited(controller.setOutcome(true));
      unawaited(controller.goToPage(2));
      firstAnswer.complete(Success<Page<AuditEntry>>(_page(totalPages: 5)));
      await firstLoad;
      await pumpEventQueue();

      // Then
      expect(currentState().query.filter.succeeded, isTrue);
      expect(currentState().query.pageNumber, 2);
    },
  );

  test(
    'GivenAFilterChangeDuringOneLoad_WhenReloaded_ThenTheChangeIsKept',
    () async {
      // Given — the first load is held open
      final firstAnswer = Completer<Result<Page<AuditEntry>>>();
      var calls = 0;
      when(anyList).thenAnswer((_) {
        calls++;

        return calls == 1
            ? firstAnswer.future
            : Future<Result<Page<AuditEntry>>>.value(
                Success<Page<AuditEntry>>(_page()),
              );
      });
      final controller = controllerUnderTest();
      final firstLoad = controller.load();

      // When
      unawaited(controller.setAction('CreateScopeCommand'));
      unawaited(controller.load());
      firstAnswer.complete(Success<Page<AuditEntry>>(_page()));
      await firstLoad;
      await pumpEventQueue();

      // Then
      expect(currentState().query.filter.action, 'CreateScopeCommand');
    },
  );

  test('GivenFilters_WhenCleared_ThenTheQueryIsUnfiltered', () async {
    // Given
    answerWith(Success<Page<AuditEntry>>(_page()));
    final controller = controllerUnderTest();
    await controller.setAction('CreateScopeCommand');
    await controller.setDays(DateTime(2026, 10, 1), DateTime(2026, 10, 2));

    // When
    await controller.clearFilters();

    // Then
    expect(currentState().query.filter.isFiltered, isFalse);
  });

  test('GivenABlankAction_WhenSet_ThenTheActionFilterIsRemoved', () async {
    // Given
    answerWith(Success<Page<AuditEntry>>(_page()));
    final controller = controllerUnderTest();
    await controller.setAction('CreateScopeCommand');

    // When
    await controller.setAction('   ');

    // Then
    expect(currentState().query.filter.action, isNull);
  });

  test('GivenARefusal_WhenLoaded_ThenTheFailureIsKeptWithTheQuery', () async {
    // Given
    answerWith(
      const FailureResult<Page<AuditEntry>>(
        Failure(kind: FailureKind.forbidden, errors: <String>[]),
      ),
    );
    final controller = controllerUnderTest();

    // When
    await controller.load();

    // Then
    expect(currentState(), isA<AuditLogFailed>());
  });

  // A sign-out resets the trail while its request is in flight, and the late
  // answer must not land in the reset state.
  test(
    'GivenALoadInFlight_WhenTheSessionResets_ThenTheAnswerIsDropped',
    () async {
      // Given
      final answer = Completer<Result<Page<AuditEntry>>>();
      when(anyList).thenAnswer((_) => answer.future);
      final controller = controllerUnderTest();

      // When
      await answerAfterReset(
        container,
        auditLogControllerProvider,
        reset: auditLogControllerProvider,
        start: controller.load,
        answer: () => answer.complete(Success<Page<AuditEntry>>(_page())),
      );

      // Then
      expect(currentState(), isA<AuditLogLoading>());
    },
  );
}
