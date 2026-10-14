import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/formatting/date_time_format.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/failure_banner.dart';
import '../domain/application_credential.dart';
import 'application_credentials_controller.dart';
import 'issue_credential_dialog.dart';
import 'one_time_secret_dialog.dart';

/// UI-37 — an application's credentials: the list, issuing one and revoking
/// one.
class CredentialsCard extends ConsumerStatefulWidget {
  const CredentialsCard({
    required this.scopeId,
    required this.applicationId,
    super.key,
  });

  final String scopeId;
  final String applicationId;

  @override
  ConsumerState<CredentialsCard> createState() => _CredentialsCardState();
}

class _CredentialsCardState extends ConsumerState<CredentialsCard> {
  CredentialsKey get _key =>
      (scopeId: widget.scopeId, applicationId: widget.applicationId);

  ApplicationCredentialsController get _controller =>
      ref.read(applicationCredentialsControllerProvider(_key).notifier);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _controller.load());
  }

  /// UC-53. The secret lives only in these locals and in the dialog.
  Future<void> _issue() async {
    // The root navigator outlives this card: if the page is left while the
    // request is in flight, the secret still has somewhere to be shown.
    final navigator = Navigator.of(context, rootNavigator: true);
    final issued = await showIssueCredentialDialog(context, _key);

    if (issued == null) {
      return;
    }

    await showOneTimeSecretDialog(
      mounted ? context : navigator.context,
      issued.secret,
    );
  }

  /// UC-55 — AF-37f: a dialog the user closes sends nothing.
  Future<void> _revoke(ApplicationCredential credential) async {
    final confirmed = await showConfirm(
      context: context,
      title: 'Revoke this credential?',
      message: 'Tokens issued from it stop working at the next check.',
      confirmLabel: 'Revoke',
    );

    if (confirmed && mounted) {
      await _controller.revoke(credential);
    }
  }

  Future<void> _copyIdentifier(String id) async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: id));
    messenger.showSnackBar(const SnackBar(content: Text('Identifier copied.')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Watched here, so the auto-disposed state lives as long as the card.
    final state = ref.watch(applicationCredentialsControllerProvider(_key));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Credentials', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'An application exchanges a secret for a token at '
              'POST /api/applications/token. At most two secrets may be live, '
              'so a new one can be deployed before the old one is revoked.',
              style: theme.textTheme.bodyMedium,
            ),
            if (state.notice case final notice?) ...<Widget>[
              const SizedBox(height: 16),
              _Notice(message: notice),
            ],
            if (state.actionFailure case final failure?) ...<Widget>[
              const SizedBox(height: 16),
              ErrorBanner(failure: failure),
            ],
            const SizedBox(height: 8),
            _list(state),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                FilledButton.icon(
                  icon: const Icon(Icons.key_outlined),
                  label: const Text('Issue credential'),
                  onPressed: state.mayIssue ? _issue : null,
                ),
                if (state.liveCount >= maxLiveCredentials)
                  Text(
                    'Revoke a credential before issuing another.',
                    style: theme.textTheme.bodySmall,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _list(CredentialsState state) {
    final credentials = state.credentials;

    if (state.loadFailure case final failure?) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ErrorBanner(failure: failure),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              onPressed: _controller.load,
              child: const Text('Retry'),
            ),
          ),
        ],
      );
    }

    if (credentials == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: LinearProgressIndicator(),
      );
    }

    if (credentials.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text('This application has no credentials yet.'),
      );
    }

    return Column(
      children: <Widget>[
        for (final credential in credentials) _row(credential, state.busy),
      ],
    );
  }

  Widget _row(ApplicationCredential c, bool busy) {
    final scheme = Theme.of(context).colorScheme;
    String dt(DateTime at) => formatDateTime(context, at);
    String orNever(DateTime? at) => at == null ? 'Never' : dt(at);

    final issued = c.createdAt == null ? '—' : dt(c.createdAt!);
    final revoked = c.revokedAt == null ? '' : ' · Revoked ${dt(c.revokedAt!)}';

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Chip(
        label: Text(switch (c.status) {
          CredentialStatus.live => 'Live',
          CredentialStatus.revoked => 'Revoked',
          CredentialStatus.expired => 'Expired',
        }),
        backgroundColor: c.status == CredentialStatus.live
            ? scheme.primaryContainer
            : null,
      ),
      title: SelectableText(c.id),
      subtitle: Text(
        'Issued $issued · Expires ${orNever(c.expiresAt)} · '
        'Last used ${orNever(c.lastUsedAt)}$revoked',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          IconButton(
            tooltip: 'Copy identifier',
            icon: const Icon(Icons.copy_outlined),
            onPressed: () => _copyIdentifier(c.id),
          ),
          if (c.revokedAt == null)
            TextButton(
              onPressed: busy ? null : () => _revoke(c),
              child: const Text('Revoke'),
            ),
        ],
      ),
    );
  }
}

/// A one-line confirmation of what the last action did.
class _Notice extends StatelessWidget {
  const _Notice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.secondaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: <Widget>[
            Icon(
              Icons.check_circle_outline,
              color: scheme.onSecondaryContainer,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: scheme.onSecondaryContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
