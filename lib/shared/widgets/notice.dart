import 'package:flutter/material.dart';

/// What the last action did, or what state the screen is in, shown beside the
/// thing it is about.
///
/// A confirmation unless [isError] is set, and never a request failure: see
/// `ErrorBanner` for that. It is a live region, so a screen reader announces
/// the notice when it appears; every notice in the application goes through
/// here so none of them is silent.
class Notice extends StatelessWidget {
  const Notice(this.message, {this.isError = false, this.icon, super.key});

  final String message;

  /// Styles the notice as a warning (the error container colours) instead of a
  /// confirmation.
  final bool isError;

  /// Defaults to a check mark, or an error mark when [isError] is set. A notice
  /// that warns rather than confirms passes its own.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = isError
        ? scheme.errorContainer
        : scheme.secondaryContainer;
    final foreground = isError
        ? scheme.onErrorContainer
        : scheme.onSecondaryContainer;

    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: <Widget>[
            Icon(
              icon ??
                  (isError ? Icons.error_outline : Icons.check_circle_outline),
              color: foreground,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message, style: TextStyle(color: foreground)),
            ),
          ],
        ),
      ),
    );
  }
}
