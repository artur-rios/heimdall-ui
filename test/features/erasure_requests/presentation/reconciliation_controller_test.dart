import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/core/network/envelope.dart';
import 'package:heimdall_ui/core/result/result.dart';
import 'package:heimdall_ui/features/erasure_requests/domain/erasure_request_repository.dart';
import 'package:heimdall_ui/features/erasure_requests/domain/outstanding_erasure.dart';
import 'package:heimdall_ui/features/erasure_requests/presentation/reconciliation_controller.dart';
import 'package:mocktail/mocktail.dart';

class _MockErasureRequestRepository extends Mock
    implements ErasureRequestRepository {}

const _a = '6f1c2b9e-0d4a-4c1e-9a3b-2f6d8e7a1b0c';

Page<OutstandingErasure> _page() => const Page<OutstandingErasure>(
  items: <OutstandingErasure>[],
  pageNumber: 1,
  pageSize: 20,
  totalItems: 0,
  totalPages: 1,
);

void main() {
  late _MockErasureRequestRepository repository;
  late ProviderContainer container;

  ReconciliationController controllerUnderTest() {
    container = ProviderContainer(
      overrides: <Override>[
        erasureRequestRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    // Keeps the auto-dispose provider alive between calls.
    container.listen(reconciliationControllerProvider, (_, _) {});

    return container.read(reconciliationControllerProvider.notifier);
  }

  ReconciliationState currentState() =>
      container.read(reconciliationControllerProvider);

  void answerListWith(Result<Page<OutstandingErasure>> result) {
    when(
      () => repository.list(
        overdueOnly: any(named: 'overdueOnly'),
        pageNumber: any(named: 'pageNumber'),
        pageSize: any(named: 'pageSize'),
      ),
    ).thenAnswer((_) async => result);
  }

  setUp(() {
    repository = _MockErasureRequestRepository();
  });

  // AF-32e
  test('GivenAnEmptyPaste_WhenChecked_ThenNothingIsSendable', () {
    // Given
    final controller = controllerUnderTest();

    // When
    final parsed = controller.check('  \n ');

    // Then
    expect(parsed, isNull);
    expect((currentState() as ReconciliationEditing).empty, isTrue);
  });

  // AF-32d
  test('GivenInvalidEntries_WhenChecked_ThenTheyAreListed', () {
    // Given
    final controller = controllerUnderTest();

    // When
    final parsed = controller.check('$_a not-an-id');

    // Then
    expect(parsed, isNull);
    expect((currentState() as ReconciliationEditing).invalid, <String>[
      'not-an-id',
    ]);
  });

  test('GivenValidIds_WhenChecked_ThenTheyAreSendable', () {
    // Given
    final controller = controllerUnderTest();

    // When
    final parsed = controller.check('$_a\n${_a.toUpperCase()}');

    // Then
    expect(parsed!.ids, <String>[_a]);
  });

  test('GivenIds_WhenSent_ThenTheOutcomeIsShownAndTheListRefreshes', () async {
    // Given
    when(() => repository.reapply(<String>[_a])).thenAnswer(
      (_) async => const Success<ReconciliationOutcome>(
        ReconciliationOutcome(
          anonymised: 1,
          alreadyAnonymised: 0,
          notFound: <String>[],
        ),
      ),
    );
    answerListWith(Success<Page<OutstandingErasure>>(_page()));
    final controller = controllerUnderTest();

    // When
    await controller.send(<String>[_a]);

    // Then
    expect((currentState() as ReconciliationDone).outcome.anonymised, 1);
    verify(() => repository.list(overdueOnly: false, pageNumber: 1)).called(1);
  });

  // AF-32g
  test('GivenARefusal_WhenSent_ThenTheErrorsAreKept', () async {
    // Given
    const refusal = Failure(
      kind: FailureKind.validation,
      errors: <String>['At least one subject identifier is required.'],
    );
    when(() => repository.reapply(any())).thenAnswer(
      (_) async => const FailureResult<ReconciliationOutcome>(refusal),
    );
    final controller = controllerUnderTest();

    // When
    await controller.send(<String>[_a]);

    // Then
    expect((currentState() as ReconciliationEditing).failure, same(refusal));
  });
}
