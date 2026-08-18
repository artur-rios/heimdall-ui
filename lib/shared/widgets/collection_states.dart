import 'package:flutter/material.dart';

import '../../core/result/result.dart';
import 'failure_banner.dart';

/// The placeholder a listing shows while its first page loads.
///
/// FR-UX-04's AF-10e: it occupies the same space the list will, so arriving
/// rows do not shift the layout under the user's pointer.
class CollectionLoading extends StatelessWidget {
  const CollectionLoading({this.rows = 6, super.key});

  final int rows;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: rows,
      itemBuilder: (context, index) => Container(
        height: 72,
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

/// What a listing shows when it has nothing to show.
///
/// FR-UX-06: "nothing here yet" and "nothing matched your filter" are different
/// situations with different next actions, so the caller says which this is.
class CollectionEmpty extends StatelessWidget {
  const CollectionEmpty({
    required this.title,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String title;
  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 48, color: theme.colorScheme.outline),
              const SizedBox(height: 16),
              Text(
                title,
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              if (actionLabel case final String label) ...<Widget>[
                const SizedBox(height: 24),
                FilledButton(onPressed: onAction, child: Text(label)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// What a listing shows when the request failed.
///
/// FR-UX-07: the filters that produced the request are untouched, so the retry
/// asks the same question again rather than a fresh one.
class CollectionFailed extends StatelessWidget {
  const CollectionFailed({
    required this.failure,
    required this.onRetry,
    super.key,
  });

  final Failure failure;

  /// `null` while a retry is already in flight.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (failure.kind == FailureKind.network)
              RetryBanner(onRetry: onRetry)
            else ...<Widget>[
              ErrorBanner(failure: failure),
              const SizedBox(height: 16),
              FilledButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ],
        ),
      ),
    ),
  );
}
