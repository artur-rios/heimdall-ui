import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/result/result.dart';
import '../../../shared/widgets/failure_banner.dart';
import '../domain/application_credential.dart';
import 'application_credentials_controller.dart';
import 'pending_secret.dart';

/// UC-53 — asks for an optional expiry and issues the credential. Answers the
/// [IssuedCredential], secret included, or `null` when cancelled (AF-37f).
///
/// The dialog cannot be left while the request is in flight: the API may be
/// about to answer with a secret that is shown once, and a dialog gone by then
/// would leave a credential that counts toward the limit and has no secret.
Future<IssuedCredential?> showIssueCredentialDialog(
  BuildContext context,
  CredentialsKey key,
) => showDialog<IssuedCredential>(
  context: context,
  barrierDismissible: false,
  builder: (context) => _IssueCredentialDialog(credentialsKey: key),
);

class _IssueCredentialDialog extends ConsumerStatefulWidget {
  const _IssueCredentialDialog({required this.credentialsKey});

  final CredentialsKey credentialsKey;

  @override
  ConsumerState<_IssueCredentialDialog> createState() =>
      _IssueCredentialDialogState();
}

class _IssueCredentialDialogState
    extends ConsumerState<_IssueCredentialDialog> {
  DateTime? _day;

  /// Whether an issue was attempted from this dialog, so a refusal of an
  /// earlier revoke on the card is not shown here.
  bool _attempted = false;

  Future<void> _pickDay() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365 * 5)),
      initialDate: _day ?? today,
    );

    if (picked != null && mounted) {
      setState(() => _day = picked);
    }
  }

  Future<void> _issue() async {
    final day = _day;
    setState(() => _attempted = true);
    // Taken before the await: choosing Leave mid-flight unmounts this dialog.
    final pending = ref.read(pendingSecretProvider.notifier);
    final controller = ref.read(
      applicationCredentialsControllerProvider(widget.credentialsKey).notifier,
    );
    // From the moment the request is sent: the answer may carry the secret.
    pending.set();

    final result = await controller.issue(
      expiresAt: day == null ? null : credentialExpiryFor(day),
    );

    if (result is FailureResult<IssuedCredential>) {
      // Refused: there is no secret to lose. An ignored call (`null`) leaves
      // the flag alone, since the first request is still running.
      pending.clear();
    }

    // `null`: another request was in flight, so nothing was sent. A failure
    // stays open with the API's message in the banner.
    if (result is Success<IssuedCredential> && mounted) {
      Navigator.of(context).pop(result.value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(
      applicationCredentialsControllerProvider(widget.credentialsKey),
    );
    final localizations = MaterialLocalizations.of(context);
    final day = _day;

    return PopScope(
      canPop: !state.busy,
      child: AlertDialog(
        scrollable: true,
        title: const Text('Issue a credential'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'An application exchanges a secret for a token at '
              'POST /api/applications/token. At most two secrets may be live, '
              'so a new one can be deployed before the old one is revoked.',
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: <Widget>[
                OutlinedButton.icon(
                  icon: const Icon(Icons.event_outlined),
                  label: Text(
                    day == null
                        ? 'Never expires'
                        : 'Expires on ${localizations.formatShortDate(day)}',
                  ),
                  onPressed: state.busy ? null : _pickDay,
                ),
                if (day != null)
                  TextButton(
                    onPressed: state.busy
                        ? null
                        : () => setState(() => _day = null),
                    child: const Text('No expiry'),
                  ),
              ],
            ),
            if (_attempted && state.actionFailure != null) ...<Widget>[
              const SizedBox(height: 16),
              ErrorBanner(failure: state.actionFailure!),
            ],
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: state.busy ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: state.mayIssue ? _issue : null,
            child: const Text('Issue'),
          ),
        ],
      ),
    );
  }
}
