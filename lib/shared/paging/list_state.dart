import '../../core/network/envelope.dart';
import '../../core/result/result.dart';

/// What every paged listing's state says, whatever the feature: the query it
/// is for. [Q] is the feature's query and [T] the row it lists.
///
/// Each feature keeps its own sealed state classes, so its screen switches over
/// them exhaustively. They implement these interfaces as well, which is what
/// lets shared code — `PagedListController` and the shared list widgets — read
/// a listing without knowing which one it is. A state implements exactly one of
/// [ListLoading], [ListLoaded] and [ListFailed].
abstract interface class ListState<Q, T> {
  /// The query this state answers, kept in every state so the filters survive
  /// a failure and a retry asks exactly what failed (FR-UX-07).
  Q get query;
}

/// Nothing has arrived for [query] yet, and the list shows a placeholder.
abstract interface class ListLoading<Q, T> implements ListState<Q, T> {}

/// A page is on screen.
abstract interface class ListLoaded<Q, T> implements ListState<Q, T> {
  Page<T> get page;

  /// A further page or filter is in flight. The rows of [page] stay on screen
  /// meanwhile instead of flashing the placeholder again, and [query] is
  /// already the one being asked.
  bool get busy;
}

/// The request for [query] failed.
abstract interface class ListFailed<Q, T> implements ListState<Q, T> {
  Failure get failure;
}
