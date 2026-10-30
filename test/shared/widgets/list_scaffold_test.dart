import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/core/network/envelope.dart' as envelope;
import 'package:heimdall_ui/core/result/result.dart';
import 'package:heimdall_ui/shared/paging/list_state.dart';
import 'package:heimdall_ui/shared/widgets/collection_states.dart';
import 'package:heimdall_ui/shared/widgets/list_scaffold.dart';

class _Loading implements ListLoading<String, int> {
  @override
  String get query => 'q';
}

class _Other implements ListState<String, int> {
  @override
  String get query => 'q';
}

/// Loaded, but not the feature's own [_Loaded] the scaffold is typed to.
class _LoadedOfAnotherKind implements ListLoaded<String, int> {
  @override
  String get query => 'q';

  @override
  bool get busy => false;

  @override
  envelope.Page<int> get page => const envelope.Page<int>(
    items: <int>[1],
    pageNumber: 1,
    pageSize: 20,
    totalItems: 1,
    totalPages: 1,
  );
}

class _Failed implements ListFailed<String, int> {
  _Failed(this.failure);

  @override
  final Failure failure;

  @override
  String get query => 'q';
}

class _Loaded implements ListLoaded<String, int> {
  _Loaded(this.items, {this.query = 'q'});

  final List<int> items;

  @override
  final String query;

  @override
  bool get busy => false;

  @override
  envelope.Page<int> get page => envelope.Page<int>(
    items: items,
    pageNumber: 1,
    pageSize: 20,
    totalItems: items.length,
    totalPages: 1,
  );
}

const _forbidden = Failure(kind: FailureKind.forbidden, errors: <String>[]);
const _server = Failure(kind: FailureKind.server, errors: <String>['Boom']);

void main() {
  late int retries;
  late int backs;

  setUp(() {
    retries = 0;
    backs = 0;
  });

  Future<void> pump(
    WidgetTester tester,
    ListState<String, int> state, {
    bool withBack = true,
    bool customForbidden = false,
  }) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ListScaffold<String, int, _Loaded>(
          state: state,
          onRetry: () => retries++,
          forbidden: !withBack
              ? null
              : customForbidden
              ? ListForbidden(
                  message: 'Only a System Admin may see this.',
                  actionLabel: 'Back to Home',
                  onAction: () => backs++,
                )
              : ListForbidden.scope(onAction: () => backs++),
          empty: (query) => Text('empty for $query'),
          loaded: (loaded) => Text('rows ${loaded.items.join(',')}'),
        ),
      ),
    ),
  );

  testWidgets('GivenALoadingState_WhenBuilt_ThenThePlaceholderShows', (
    tester,
  ) async {
    await pump(tester, _Loading());

    expect(find.byType(CollectionLoading), findsOneWidget);
  });

  testWidgets('GivenAStateOfNoKnownKind_WhenBuilt_ThenItIsLoading', (
    tester,
  ) async {
    await pump(tester, _Other());

    expect(find.byType(CollectionLoading), findsOneWidget);
  });

  testWidgets('GivenAFailure_WhenRetryIsTapped_ThenItAsksAgain', (
    tester,
  ) async {
    await pump(tester, _Failed(_server));

    await tester.tap(find.widgetWithText(FilledButton, 'Retry'));

    expect(find.byType(CollectionFailed), findsOneWidget);
    expect(retries, 1);
  });

  testWidgets('GivenForbidden_WhenTheListingHasAWayBack_ThenItIsOffered', (
    tester,
  ) async {
    await pump(tester, _Failed(_forbidden));

    expect(find.text('Not available for your role'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Back to scopes'));
    expect(backs, 1);
  });

  testWidgets('GivenForbidden_WhenTheListingSaysItsOwnWords_ThenTheyShow', (
    tester,
  ) async {
    await pump(tester, _Failed(_forbidden), customForbidden: true);

    expect(find.text('Only a System Admin may see this.'), findsOneWidget);
    expect(find.textContaining('scope'), findsNothing);
    await tester.tap(find.widgetWithText(FilledButton, 'Back to Home'));
    expect(backs, 1);
  });

  testWidgets('GivenALoadedStateOfAnotherKind_WhenBuilt_ThenDebugRefusesIt', (
    tester,
  ) async {
    await pump(tester, _LoadedOfAnotherKind());

    expect(tester.takeException(), isA<AssertionError>());
  });

  testWidgets('GivenForbidden_WhenTheListingHasNoWayBack_ThenItIsAFailure', (
    tester,
  ) async {
    await pump(tester, _Failed(_forbidden), withBack: false);

    expect(find.text('Not available for your role'), findsNothing);
    expect(find.byType(CollectionFailed), findsOneWidget);
  });

  testWidgets('GivenAnEmptyPage_WhenBuilt_ThenTheEmptyBuilderGetsTheQuery', (
    tester,
  ) async {
    await pump(tester, _Loaded(const <int>[], query: 'abc'));

    expect(find.text('empty for abc'), findsOneWidget);
  });

  testWidgets('GivenAPageOfRows_WhenBuilt_ThenTheRowsBuilderGetsTheState', (
    tester,
  ) async {
    await pump(tester, _Loaded(const <int>[1, 2]));

    expect(find.text('rows 1,2'), findsOneWidget);
  });
}
