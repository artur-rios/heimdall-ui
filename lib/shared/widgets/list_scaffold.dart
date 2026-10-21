import 'package:flutter/material.dart';

import '../../core/result/result.dart';
import '../paging/list_state.dart';
import 'collection_states.dart';

/// What a listing shows for its [state]: the placeholder while the first page
/// loads, the failure with a retry, the empty message, or the rows.
///
/// The states are interfaces rather than a sealed family, so a state that is
/// neither failed nor loaded is read as loading, which is the one thing left
/// for it to be.
class ListScaffold<Q, T, L extends ListLoaded<Q, T>> extends StatelessWidget {
  const ListScaffold({
    required this.state,
    required this.onRetry,
    required this.empty,
    required this.loaded,
    this.onForbiddenBack,
    super.key,
  });

  final ListState<Q, T> state;

  /// Asks for the same query again, which a failure leaves untouched
  /// (FR-UX-07).
  final VoidCallback onRetry;

  /// What an empty page says, given the query that produced it: "nothing here
  /// yet" and "nothing matched" are different situations (FR-UX-06).
  final Widget Function(Q query) empty;

  /// The rows of a page that has some. [L] is the feature's own loaded state,
  /// for a screen that reads more from it than the page.
  final Widget Function(L state) loaded;

  /// Where a forbidden answer sends the admin, for a listing that belongs to a
  /// scope they may not administer. `null` for a listing with no such answer,
  /// whose forbidden failure is shown like any other.
  final VoidCallback? onForbiddenBack;

  @override
  Widget build(BuildContext context) => switch (state) {
    ListFailed(:final failure)
        when failure.kind == FailureKind.forbidden && onForbiddenBack != null =>
      CollectionEmpty(
        title: 'Not available for your role',
        message:
            'This scope is not one you administer. Nothing is wrong with '
            'your session.',
        icon: Icons.lock_person_outlined,
        actionLabel: 'Back to scopes',
        onAction: onForbiddenBack,
      ),
    ListFailed(:final failure) => CollectionFailed(
      failure: failure,
      onRetry: onRetry,
    ),
    final ListLoaded<Q, T> page when page.page.items.isEmpty => empty(
      page.query,
    ),
    final L page => loaded(page),
    _ => const CollectionLoading(),
  };
}
