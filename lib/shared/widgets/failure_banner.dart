import 'package:flutter/material.dart';

import '../../core/result/result.dart';

/// Says that the API could not be reached, and offers the only action that
/// helps. A transport failure carries no errors of the API's own, so there is
/// nothing of its to render here.
class RetryBanner extends StatelessWidget {
  const RetryBanner({required this.onRetry, super.key});

  /// `null` while a retry is already in flight, which disables the control.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Could not reach the API. Check your connection and try again.',
            style: TextStyle(color: scheme.onErrorContainer),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(onPressed: onRetry, child: const Text('Retry')),
          ),
        ],
      ),
    );
  }
}

/// Shows the API's own error strings, unaltered, so what a user reads matches
/// what an operator finds in the API's logs.
class ErrorBanner extends StatelessWidget {
  const ErrorBanner({required this.failure, super.key});

  final Failure failure;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final messages = failure.errors.isNotEmpty
        ? failure.errors
        : <String>[failure.displayMessage];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (final message in messages)
            Text(message, style: TextStyle(color: scheme.onErrorContainer)),
        ],
      ),
    );
  }
}
