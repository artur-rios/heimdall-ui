import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// UC-53's secret, shown once. The dialog cannot be dismissed by a tap outside,
/// Escape or Back: the only way on is to say it has been stored, because there
/// is no second chance to see it.
Future<void> showOneTimeSecretDialog(BuildContext context, String secret) =>
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          scrollable: true,
          title: const Text('Store this secret now'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                "This is the only time the secret is shown. Store it in the application's secret store now.",
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  secret,
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  icon: const Icon(Icons.copy_outlined),
                  label: const Text('Copy'),
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    await Clipboard.setData(ClipboardData(text: secret));
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Secret copied.')),
                    );
                  },
                ),
              ),
            ],
          ),
          actions: <Widget>[
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("I've stored it"),
            ),
          ],
        ),
      ),
    );
