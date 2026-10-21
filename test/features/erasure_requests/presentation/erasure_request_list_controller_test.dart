import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/core/network/envelope.dart';
import 'package:heimdall_ui/core/result/result.dart';
import 'package:heimdall_ui/features/erasure_requests/domain/erasure_request_repository.dart';
import 'package:heimdall_ui/features/erasure_requests/domain/outstanding_erasure.dart';
import 'package:heimdall_ui/features/erasure_requests/presentation/erasure_request_list_controller.dart';
import 'package:mocktail/mocktail.dart';

import '../../../support/held_answer.dart';

class _MockErasureRequestRepository extends Mock
    implements ErasureRequestRepository {}

const _someone = OutstandingErasure(
  subjectId: '6f1c2b9e-0d4a-4c1e-9a3b-2f6d8e7a1b0c',
  isGoogleUser: false,
  overdue: false,
);

Page<OutstandingErasure> _page({
  List<OutstandingErasure> items = const <OutstandingErasure>[_someone],
  int totalPages = 1,
}) => Page<OutstandingErasure>(
  items: items,
  pageNumber: 1,
  pageSize: 20,
  totalItems: items.length,
  totalPages: totalPages,
);

void main() {
  late _MockErasureRequestRepository repository;
  late ProviderContainer container;

  ErasureRequestListController controllerUnderTest() {
    container = ProviderContainer(
      overrides: <Override>[
        erasureRequestRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    return container.read(erasureRequestListControllerProvider.notifier);
  }

  ErasureRequestListState currentState() =>
      container.read(erasureRequestListControllerProvider);

  Future<Result<Page<OutstandingErasure>>> anyList() => repository.list(
    overdueOnly: any(named: 'overdueOnly'),
    pageNumber: any(named: 'pageNumber'),
    pageSize: any(named: 'pageSize'),
  );

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

  test('GivenAPage_WhenLoaded_ThenTheFirstPageIsShown', () async {
    // Given
    answerListWith(Success<Page<OutstandingErasure>>(_page()));
    final controller = controllerUnderTest();

    // When
    await controller.load();

    // Then
    verify(() => repository.list(overdueOnly: false, pageNumber: 1)).called(1);
    expect(
      (currentState() as ErasureRequestListLoaded).page.items.single.subjectId,
      _someone.subjectId,
    );
  });

  test('GivenOverdueOnly_WhenSet_ThenTheFirstPageIsAskedForFiltered', () async {
    // Given
    answerListWith(Success<Page<OutstandingErasure>>(_page()));
    final controller = controllerUnderTest();
    await controller.load();

    // When
    await controller.setOverdueOnly(true);

    // Then
    verify(() => repository.list(overdueOnly: true, pageNumber: 1)).called(1);
    expect(currentState().query.overdueOnly, isTrue);
  });

  test('GivenAFilter_WhenAnotherPageIsAsked_ThenTheFilterIsKept', () async {
    // Given
    answerListWith(Success<Page<OutstandingErasure>>(_page(totalPages: 3)));
    final controller = controllerUnderTest();
    await controller.setOverdueOnly(true);

    // When
    await controller.goToPage(2);

    // Then
    verify(() => repository.list(overdueOnly: true, pageNumber: 2)).called(1);
    expect(currentState().query.overdueOnly, isTrue);
  });

  // #157 — a filter queued during a load, then a page change: the request
  // that follows the load carries both.
  test('GivenAFilterQueuedDuringALoad_WhenAnotherPageIsAsked_ThenTheLastRequestCarriesBoth', () async {
    // Given
    final first = Completer<Result<Page<OutstandingErasure>>>();
    when(anyList).thenAnswer(
      heldFirstAnswer(
        first,
        () => Success<Page<OutstandingErasure>>(_page(totalPages: 5)),
      ),
    );
    final controller = controllerUnderTest();
    final loading = controller.load();

    // When
    unawaited(controller.setOverdueOnly(true));
    unawaited(controller.goToPage(3));
    first.complete(Success<Page<OutstandingErasure>>(_page(totalPages: 5)));
    await loading;

    // Then
    verify(() => repository.list(overdueOnly: true, pageNumber: 3)).called(1);
    expect(currentState().query.overdueOnly, isTrue);
    expect(currentState().query.pageNumber, 3);
  });
}
