import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/core/network/envelope.dart';
import 'package:heimdall_ui/core/result/result.dart';
import 'package:heimdall_ui/shared/paging/list_state.dart';
import 'package:heimdall_ui/shared/paging/paged_list_controller.dart';

import '../../support/late_answer.dart';

/// The engine is stated once here, against a listing that has the filters
/// most features have: a name, an include-deleted switch, and a page.
typedef _Query = ({String name, bool includeDeleted, int pageNumber});

const _Query _initial = (name: '', includeDeleted: false, pageNumber: 1);

_Query _query({String name = '', bool includeDeleted = false, int page = 1}) =>
    (name: name, includeDeleted: includeDeleted, pageNumber: page);

sealed class _State implements ListState<_Query, String> {
  const _State(this.query);

  @override
  final _Query query;
}

final class _Loading extends _State implements ListLoading<_Query, String> {
  const _Loading(super.query);
}

final class _Loaded extends _State implements ListLoaded<_Query, String> {
  const _Loaded(super.query, this.page, {this.busy = false});

  @override
  final Page<String> page;

  @override
  final bool busy;
}

final class _Failed extends _State implements ListFailed<_Query, String> {
  const _Failed(super.query, this.failure);

  @override
  final Failure failure;
}

Page<String> _page(int pageNumber, {bool empty = false, int totalPages = 5}) =>
    Page<String>(
      items: empty ? const <String>[] : <String>['row on page $pageNumber'],
      pageNumber: pageNumber,
      pageSize: 20,
      totalItems: empty ? 0 : 1,
      totalPages: totalPages,
    );

/// The repository behind the probe: it records every query asked, can hold
/// the next answer open, and answers the rest with [answer].
class _Api {
  final List<_Query> asked = <_Query>[];

  Future<Result<Page<String>>> Function(_Query query) answer = (query) =>
      Future<Result<Page<String>>>.value(
        Success<Page<String>>(_page(query.pageNumber)),
      );

  bool _holdNext = false;
  Completer<Result<Page<String>>>? _held;

  /// The next request waits until [release] or [fail].
  void holdNext() => _holdNext = true;

  void release([Result<Page<String>>? result]) =>
      _held!.complete(result ?? Success<Page<String>>(_page(1)));

  void fail(Object error) => _held!.completeError(error);

  Future<Result<Page<String>>> call(_Query query) {
    asked.add(query);

    if (_holdNext) {
      _holdNext = false;
      _held = Completer<Result<Page<String>>>();

      return _held!.future;
    }

    return answer(query);
  }
}

/// A listing the way a feature writes one: the hooks, and its filter methods
/// built on `latest`.
class _Probe extends PagedListController<_Query, String, _State> {
  _Probe(this._api);

  final _Api _api;

  @override
  _Query get initialQuery => _initial;

  @override
  int pageNumberOf(_Query query) => query.pageNumber;

  @override
  _Query withPageNumber(_Query query, int pageNumber) => (
    name: query.name,
    includeDeleted: query.includeDeleted,
    pageNumber: pageNumber,
  );

  @override
  Future<Result<Page<String>>> fetch(_Query query) => _api.call(query);

  @override
  _State loadingState(_Query query) => _Loading(query);

  @override
  _State loadedState(_Query query, Page<String> page, {bool busy = false}) =>
      _Loaded(query, page, busy: busy);

  @override
  _State failedState(_Query query, Failure failure) => _Failed(query, failure);

  Future<void> search(String name) => request((
    name: name,
    includeDeleted: latest.includeDeleted,
    pageNumber: 1,
  ));

  Future<void> setIncludeDeleted(bool includeDeleted) => request((
    name: latest.name,
    includeDeleted: includeDeleted,
    pageNumber: 1,
  ));
}

const _refused = Failure(kind: FailureKind.network, errors: <String>[]);

void main() {
  late _Api api;
  late ProviderContainer container;
  late NotifierProvider<_Probe, _State> provider;

  _Probe probeUnderTest() {
    container = ProviderContainer();
    addTearDown(container.dispose);
    // Listened to, as the screen showing it would be.
    final subscription = container.listen<_State>(provider, (_, _) {});
    addTearDown(subscription.close);

    return container.read(provider.notifier);
  }

  _State currentState() => container.read(provider);

  setUp(() {
    api = _Api();
    provider = NotifierProvider<_Probe, _State>(() => _Probe(api));
  });

  group('queued queries', () {
    // Each scenario changes the listing twice while its first load is held
    // open: the request that follows the load is the query both changes make
    // together, and no request in between is sent.
    final scenarios =
        <
          ({
            String when,
            List<Future<void> Function(_Probe probe)> changes,
            _Query expected,
          })
        >[
          // #157
          (
            when: 'ASearchThenIncludeDeleted',
            changes: <Future<void> Function(_Probe)>[
              (probe) => probe.search('abc'),
              (probe) => probe.setIncludeDeleted(true),
            ],
            expected: _query(name: 'abc', includeDeleted: true),
          ),
          (
            when: 'IncludeDeletedThenASearch',
            changes: <Future<void> Function(_Probe)>[
              (probe) => probe.setIncludeDeleted(true),
              (probe) => probe.search('abc'),
            ],
            expected: _query(name: 'abc', includeDeleted: true),
          ),
          (
            when: 'APageThenASearch',
            changes: <Future<void> Function(_Probe)>[
              (probe) => probe.goToPage(3),
              (probe) => probe.search('abc'),
            ],
            expected: _query(name: 'abc'),
          ),
          (
            when: 'ASearchThenAPage',
            changes: <Future<void> Function(_Probe)>[
              (probe) => probe.search('abc'),
              (probe) => probe.goToPage(3),
            ],
            expected: _query(name: 'abc', page: 3),
          ),
          (
            when: 'ASearchThenAReload',
            changes: <Future<void> Function(_Probe)>[
              (probe) => probe.search('abc'),
              (probe) => probe.load(),
            ],
            expected: _query(name: 'abc'),
          ),
          (
            when: 'TwoPages',
            changes: <Future<void> Function(_Probe)>[
              (probe) => probe.goToPage(2),
              (probe) => probe.goToPage(3),
            ],
            expected: _query(page: 3),
          ),
          (
            when: 'TwoSearches',
            changes: <Future<void> Function(_Probe)>[
              (probe) => probe.search('first'),
              (probe) => probe.search('second'),
            ],
            expected: _query(name: 'second'),
          ),
        ];

    for (final scenario in scenarios) {
      test(
        'GivenALoadInFlight_When${scenario.when}_ThenTheNextRequestIsTheLatestQuery',
        () async {
          // Given
          api.holdNext();
          final probe = probeUnderTest();
          final loading = probe.load();

          // When
          for (final change in scenario.changes) {
            unawaited(change(probe));
          }

          // Then — nothing races the request in flight
          expect(api.asked, <_Query>[_initial]);

          // …and once it is answered, the combined query is asked, once
          api.release();
          await loading;
          expect(api.asked, <_Query>[_initial, scenario.expected]);
          expect(currentState(), isA<_Loaded>());
          expect(currentState().query, scenario.expected);
        },
      );
    }

    test(
      'GivenAQueuedQuery_WhenTheRequestInFlightIsRefused_ThenItIsStillAsked',
      () async {
        // Given
        api.holdNext();
        final probe = probeUnderTest();
        final loading = probe.load();
        unawaited(probe.search('abc'));

        // When
        api.release(const FailureResult<Page<String>>(_refused));
        await loading;

        // Then
        expect(api.asked.last, _query(name: 'abc'));
        expect(currentState(), isA<_Loaded>());
      },
    );

    test(
      'GivenAQueuedQuery_WhenTheRequestInFlightThrows_ThenItIsStillAsked',
      () async {
        // Given
        api.holdNext();
        final probe = probeUnderTest();
        final loading = probe.load();
        unawaited(probe.search('abc'));

        // When
        api.fail(const FormatException('not a page'));
        await loading;

        // Then
        expect(api.asked.last, _query(name: 'abc'));
        expect(currentState(), isA<_Loaded>());
      },
    );

    test('GivenAQueuedQuery_WhenAnEmptyPagePastTheEndArrives_ThenTheQueuedQueryWins', () async {
      // Given — page four is asked, and has gone by the time it is answered
      final probe = probeUnderTest();
      await probe.load();
      api.holdNext();
      final paging = probe.goToPage(4);
      unawaited(probe.search('abc'));

      // When
      api.release(Success<Page<String>>(_page(4, empty: true, totalPages: 2)));
      await paging;

      // Then — no step back to page two: the search is what was asked last
      expect(api.asked, <_Query>[
        _initial,
        _query(page: 4),
        _query(name: 'abc'),
      ]);
      expect(currentState().query, _query(name: 'abc'));
    });
  });

  group('a page past the end', () {
    // Each scenario asks for page [from] after rows went away: only pages up to
    // [realPages] still have rows, and an empty page reports [totalPages].
    final scenarios =
        <({int from, int totalPages, int realPages, List<int> asked})>[
          (from: 2, totalPages: 1, realPages: 1, asked: <int>[2, 1]),
          (from: 7, totalPages: 3, realPages: 3, asked: <int>[7, 3]),
          // The total is stale too: the steps go on until a page has rows.
          (from: 5, totalPages: 3, realPages: 2, asked: <int>[5, 3, 2]),
          // A total no smaller than the page asked never moves forward.
          (from: 4, totalPages: 9, realPages: 3, asked: <int>[4, 3]),
          // Everything went: the first page, empty, is where it stops.
          (from: 3, totalPages: 0, realPages: 0, asked: <int>[3, 1]),
          (from: 1, totalPages: 0, realPages: 0, asked: <int>[1]),
        ];

    for (final scenario in scenarios) {
      test(
        'GivenPage${scenario.from}Of${scenario.realPages}_WhenItArrivesEmpty_ThenPages${scenario.asked.join('And')}AreAsked',
        () async {
          // Given
          api.answer = (query) => Future<Result<Page<String>>>.value(
            Success<Page<String>>(
              query.pageNumber <= scenario.realPages
                  ? _page(query.pageNumber, totalPages: scenario.realPages)
                  : _page(
                      query.pageNumber,
                      empty: true,
                      totalPages: scenario.totalPages,
                    ),
            ),
          );
          final probe = probeUnderTest();

          // When
          await probe.goToPage(scenario.from);

          // Then
          expect(api.asked.map((query) => query.pageNumber), scenario.asked);
          expect(currentState().query.pageNumber, scenario.asked.last);
          expect(currentState(), isA<_Loaded>());
        },
      );
    }

    test(
      'GivenAFilteredPagePastTheEnd_WhenSteppedBack_ThenTheFiltersStay',
      () async {
        // Given
        api.answer = (query) => Future<Result<Page<String>>>.value(
          Success<Page<String>>(
            query.pageNumber == 1
                ? _page(1, totalPages: 1)
                : _page(query.pageNumber, empty: true, totalPages: 1),
          ),
        );
        final probe = probeUnderTest();
        await probe.setIncludeDeleted(true);

        // When
        await probe.goToPage(2);

        // Then
        expect(api.asked.last, _query(includeDeleted: true));
      },
    );
  });

  group('states', () {
    test('GivenNothingAsked_WhenBuilt_ThenTheInitialQueryIsLoading', () {
      // When
      probeUnderTest();

      // Then
      expect(currentState(), isA<_Loading>());
      expect(currentState().query, _initial);
      expect(api.asked, isEmpty);
    });

    test(
      'GivenAPageOnScreen_WhenAnotherIsAsked_ThenItsRowsStayBusyUntilAnswered',
      () async {
        // Given
        final probe = probeUnderTest();
        await probe.load();
        api.holdNext();

        // When
        final paging = probe.goToPage(2);

        // Then — the first page's rows, busy, under the query being asked
        final busy = currentState() as _Loaded;
        expect(busy.busy, isTrue);
        expect(busy.query, _query(page: 2));
        expect(busy.page.items, <String>['row on page 1']);

        api.release(Success<Page<String>>(_page(2)));
        await paging;
        final loaded = currentState() as _Loaded;
        expect(loaded.busy, isFalse);
        expect(loaded.page.items, <String>['row on page 2']);
      },
    );

    test(
      'GivenAFailure_WhenAnotherQueryIsAsked_ThenThePlaceholderShows',
      () async {
        // Given
        api.answer = (_) => Future<Result<Page<String>>>.value(
          const FailureResult<Page<String>>(_refused),
        );
        final probe = probeUnderTest();
        await probe.load();
        api.holdNext();

        // When
        final searching = probe.search('abc');

        // Then
        expect(currentState(), isA<_Loading>());
        expect(currentState().query, _query(name: 'abc'));
        api.release();
        await searching;
      },
    );

    test(
      'GivenARefusal_WhenAnswered_ThenTheFailureKeepsTheQueryThatFailed',
      () async {
        // Given
        api.answer = (_) => Future<Result<Page<String>>>.value(
          const FailureResult<Page<String>>(_refused),
        );
        final probe = probeUnderTest();

        // When
        await probe.search('abc');

        // Then
        final failed = currentState() as _Failed;
        expect(failed.failure, _refused);
        expect(failed.query, _query(name: 'abc'));
      },
    );

    test(
      'GivenAFailure_WhenReloaded_ThenTheQueryThatFailedIsAskedAgain',
      () async {
        // Given
        api.answer = (_) => Future<Result<Page<String>>>.value(
          const FailureResult<Page<String>>(_refused),
        );
        final probe = probeUnderTest();
        await probe.search('abc');
        api.answer = (query) => Future<Result<Page<String>>>.value(
          Success<Page<String>>(_page(query.pageNumber)),
        );

        // When
        await probe.load();

        // Then
        expect(api.asked, <_Query>[_query(name: 'abc'), _query(name: 'abc')]);
        expect(currentState(), isA<_Loaded>());
      },
    );
  });

  group('an answer the client cannot read', () {
    final unreadable = <({String kind, Object error})>[
      (kind: 'AFormatException', error: const FormatException('not a page')),
      (kind: 'ATypeError', error: TypeError()),
    ];

    for (final scenario in unreadable) {
      test(
        'GivenAFetchThatThrows${scenario.kind}_WhenLoaded_ThenTheStateIsFailedAsUnexpected',
        () async {
          // Given
          api.answer = (_) =>
              Future<Result<Page<String>>>.error(scenario.error);
          final probe = probeUnderTest();

          // When
          await probe.load();

          // Then
          final failed = currentState() as _Failed;
          expect(failed.failure.kind, FailureKind.unknown);
          expect(
            failed.failure.displayMessage,
            'The API returned an unexpected response.',
          );
        },
      );
    }

    test('GivenAFetchThatThrowsAnotherError_WhenLoaded_ThenItPropagatesAndTheListCanAskAgain', () async {
      // Given
      api.answer = (_) =>
          Future<Result<Page<String>>>.error(StateError('a bug'));
      final probe = probeUnderTest();

      // When / Then
      await expectLater(probe.load(), throwsA(isA<StateError>()));
      api.answer = (query) => Future<Result<Page<String>>>.value(
        Success<Page<String>>(_page(query.pageNumber)),
      );
      await probe.load();
      expect(currentState(), isA<_Loaded>());
    });
  });

  group('a reset', () {
    // A sign-out resets the listing while its request is in flight, and the
    // late answer, the previous session's rows, must not land in the reset
    // state.
    test(
      'GivenALoadInFlight_WhenTheSessionResets_ThenTheAnswerIsDropped',
      () async {
        // Given
        api.holdNext();
        final probe = probeUnderTest();

        // When
        await answerAfterReset(
          container,
          provider,
          reset: provider,
          start: probe.load,
          answer: api.release,
        );

        // Then
        expect(currentState(), isA<_Loading>());
        expect(currentState().query, _initial);
      },
    );

    test(
      'GivenAQueryQueuedBeforeAReset_WhenTheOldAnswerLands_ThenItIsNotAsked',
      () async {
        // Given
        api.holdNext();
        final probe = probeUnderTest();
        final loading = probe.load();
        unawaited(probe.search('abc'));

        // When
        container.invalidate(provider);
        container.read(provider);
        api.release();
        await loading;
        await pumpEventQueue();

        // Then
        expect(api.asked, <_Query>[_initial]);
        expect(currentState().query, _initial);
      },
    );

    test(
      'GivenALoadInFlight_WhenTheSessionResets_ThenTheNewBuildAsksAtOnce',
      () async {
        // Given
        api.holdNext();
        final probe = probeUnderTest();
        final stale = probe.load();
        container.invalidate(provider);
        container.read(provider);

        // When
        await probe.search('abc');

        // Then — not queued behind the earlier build's request
        expect(api.asked, <_Query>[_initial, _query(name: 'abc')]);
        expect(currentState().query, _query(name: 'abc'));
        api.release();
        await stale;
        expect(currentState().query, _query(name: 'abc'));
      },
    );

    test('GivenAnAutoDisposedListing_WhenItsLoadIsAnsweredAfterItWasLeft_ThenNothingIsWritten', () async {
      // Given — a listing that goes with its screen
      final autoDisposed = NotifierProvider.autoDispose<_Probe, _State>(
        () => _Probe(api),
      );
      container = ProviderContainer();
      addTearDown(container.dispose);
      final subscription = container.listen<_State>(autoDisposed, (_, _) {});
      api.holdNext();
      final loading = container.read(autoDisposed.notifier).load();

      // When — the screen is left, and only then is the load answered
      subscription.close();
      await pumpEventQueue();
      api.release();

      // Then — the answer lands nowhere and nothing throws
      await expectLater(loading, completes);
    });
  });
}
