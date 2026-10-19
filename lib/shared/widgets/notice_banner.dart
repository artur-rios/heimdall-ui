import 'package:flutter/material.dart';

/// What the last action did, shown beside what it changed.
///
/// A confirmation rather than a failure: see `ErrorBanner` for the latter.
class NoticeBanner extends StatelessWidget {
  const NoticeBanner({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // A live region, so a screen reader announces the notice when it appears.
    return Semantics(
      liveRegion: true,
      container: true,
      child: Card(
        color: scheme.secondaryContainer,
        child: ListTile(
          leading: Icon(
            Icons.check_circle_outline,
            color: scheme.onSecondaryContainer,
          ),
          title: Text(
            message,
            style: TextStyle(color: scheme.onSecondaryContainer),
          ),
        ),
      ),
    );
  }
}
