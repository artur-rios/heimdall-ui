import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/result/result.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/failure_banner.dart';
import '../../auth/domain/google_sign_in_gateway.dart';
import '../../auth/domain/session.dart';
import '../../auth/presentation/google_button.dart';
import '../../auth/presentation/session_controller.dart';
import '../domain/data_rights.dart';
import 'restricted_session_controller.dart';

/// UI-30 — what a person whose processing is restricted can do.
///
/// The API admits their token to four endpoints and refuses it everywhere
/// else, so this is the whole application for them: the guard sends every
/// other route here. It stands apart from the shell on purpose — the shell's
/// navigation would only offer screens that cannot answer.
class RestrictedSessionScreen extends ConsumerWidget {
  const RestrictedSessionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(restrictedSessionControllerProvider);
    final controller = ref.read(restrictedSessionControllerProvider.notifier);
    final session = ref.watch(sessionControllerProvider);
    final name = switch (session) {
      Authenticated(:final principal) => principal.displayName,
      _ => '',
    };
    final idle = state.busy == null;

    return Scaffold(
      appBar: AppBar(title: const Text('Restricted account')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Icon(
                    Icons.pause_circle_outline,
                    size: 48,
                    color: theme.colorScheme.primary,
                    semanticLabel: 'Restricted',
                  ),
                  const SizedBox(height: 16),
                  Semantics(
                    header: true,
                    child: Text(
                      'Processing of your account is restricted',
                      style: theme.textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  if (name.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(
                      'Signed in as $name',
                      style: theme.textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    'You asked for processing of your account to be '
                    'restricted. While it is, Heimdall keeps your data '
                    'exactly as it is and uses it for nothing else, so the '
                    'rest of the application is not available to you.',
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Only these actions are available until the restriction '
                    'is lifted.',
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 24),
                  if (state.failure case final Failure failure) ...<Widget>[
                    ErrorBanner(failure: _shown(failure)),
                    const SizedBox(height: 16),
                  ],
                  if (state.exported) ...<Widget>[
                    _Notice(
                      state.exportedTo == null
                          ? 'Your data was handed to your browser as a '
                                'download.'
                          : 'Your data was saved to ${state.exportedTo}.',
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (state.erasure
                      case final ErasureRequest erasure) ...<Widget>[
                    _Notice(_erasureOutcome(context, erasure)),
                    const SizedBox(height: 16),
                  ],
                  _ActionCard(
                    icon: Icons.lock_open_outlined,
                    title: 'Lift the restriction',
                    description:
                        'Heimdall will process your account normally again. '
                        'You will be signed out, and signing in again gives '
                        'you your full access back.',
                    action: FilledButton(
                      onPressed: idle ? () => _lift(context, ref) : null,
                      child: _Label(
                        'Lift the restriction',
                        busy: state.busy == RestrictedSessionAction.lifting,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _ActionCard(
                    icon: Icons.download_outlined,
                    title: 'Download my data',
                    description:
                        'A copy of everything Heimdall holds about you, with '
                        'who receives it and how long it is kept, as a JSON '
                        'file.',
                    action: OutlinedButton(
                      onPressed: idle ? controller.exportData : null,
                      child: _Label(
                        'Download my data',
                        busy: state.busy == RestrictedSessionAction.exporting,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _ErasureCard(
                    busy: state.busy == RestrictedSessionAction.erasing,
                    enabled: idle && state.erasure == null,
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: idle ? controller.signOut : null,
                    icon: const Icon(Icons.logout),
                    label: const Text('Sign out'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => context.push('/privacy'),
                    child: const Text('Privacy notice'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Asks first: lifting resumes processing, and with it any erasure the
  /// person requested while restricted.
  Future<void> _lift(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(restrictedSessionControllerProvider.notifier);
    final confirmed = await showConfirm(
      context: context,
      title: 'Lift the restriction?',
      message:
          'Heimdall will process your account normally again. If you have '
          'asked for your account to be erased, that goes ahead once the '
          'restriction is lifted. You will be signed out, and can then sign in '
          'again with full access.',
      confirmLabel: 'Lift the restriction',
    );

    if (confirmed) {
      await controller.liftRestriction();
    }
  }

  /// A transport failure carries no words of the API's own, so it is given
  /// some; everything else is shown as the API said it.
  static Failure _shown(Failure failure) => failure.kind == FailureKind.network
      ? const Failure(
          kind: FailureKind.network,
          errors: <String>[
            'Could not reach the API. Check your connection and try again.',
          ],
        )
      : failure;

  static String _erasureOutcome(BuildContext context, ErasureRequest erasure) {
    final localizations = MaterialLocalizations.of(context);
    String date(DateTime? at) =>
        at == null ? '' : localizations.formatFullDate(at.toLocal());
    final due = erasure.dueAt == null
        ? ''
        : ' It is due by ${date(erasure.dueAt)}.';

    if (erasure.blocked) {
      // AF-30f: recorded, and the deadline runs, but not suspended yet.
      return 'Your erasure request was recorded.$due Your account cannot be '
          'suspended yet: ${erasure.blockedReason ?? 'something is blocking it.'}';
    }

    return 'Your erasure request was recorded.$due While processing of your '
        'account is restricted, your data is kept as it is: the erasure is '
        'carried out once the restriction is lifted.';
  }
}

/// One of the actions, with what it does said before it is offered.
class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.action,
    this.note,
  });

  final IconData icon;
  final String title;
  final String description;
  final Widget action;

  /// A line under the action, for when it cannot be taken here.
  final String? note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(icon, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(title, style: theme.textTheme.titleMedium),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(description, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 16),
            Align(alignment: Alignment.centerRight, child: action),
            if (note case final String note) ...<Widget>[
              const SizedBox(height: 8),
              Text(note, style: theme.textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}

/// The erasure request, confirmed the way the person signs in: with their
/// password, or — for a Google User — with Google (UC-42 step 1).
class _ErasureCard extends ConsumerWidget {
  const _ErasureCard({required this.busy, required this.enabled});

  final bool busy;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);
    final viaGoogle = session is Authenticated && session.token.viaGoogle;
    final googleAvailability =
        ref.watch(appConfigProvider).isGoogleSignInConfigured
        ? ref.watch(googleSignInGatewayProvider).availability
        : GoogleSignInAvailability.unsupported;
    // AF-30h: a Google User confirms with a fresh Google ID token, which a
    // build or target without Google's flow cannot obtain.
    final confirmable =
        !viaGoogle ||
        googleAvailability != GoogleSignInAvailability.unsupported;

    return _ActionCard(
      icon: Icons.delete_forever_outlined,
      title: 'Request erasure',
      description:
          'Asks for your account and the data held about it to be erased. '
          'This cannot be undone. Your account is suspended at once, and the '
          'erasure is carried out by a deadline — but while processing is '
          'restricted, it waits until the restriction is lifted.',
      action: OutlinedButton(
        onPressed: enabled && confirmable
            ? () => _request(context, ref, viaGoogle, googleAvailability)
            : null,
        child: _Label('Request erasure', busy: busy),
      ),
      note: confirmable
          ? null
          : 'Erasure is confirmed by signing in with Google again, which is '
                'not available here. Request it from a device where you can '
                'sign in with Google.',
    );
  }

  Future<void> _request(
    BuildContext context,
    WidgetRef ref,
    bool viaGoogle,
    GoogleSignInAvailability availability,
  ) async {
    final controller = ref.read(restrictedSessionControllerProvider.notifier);

    if (!viaGoogle) {
      final password = await showDialog<String>(
        context: context,
        builder: (context) => const _PasswordErasureDialog(),
      );

      if (password != null) {
        await controller.requestErasure(PasswordCredential(password));
      }

      return;
    }

    if (availability == GoogleSignInAvailability.platformControl) {
      // The web: Google renders its own button, and the token arrives on the
      // gateway's stream rather than from a call.
      final idToken = await showDialog<String>(
        context: context,
        builder: (context) => const _GoogleErasureDialog(),
      );

      if (idToken != null) {
        await controller.requestErasure(GoogleIdTokenCredential(idToken));
      }

      return;
    }

    if (!context.mounted) {
      return;
    }

    final confirmed = await showConfirm(
      context: context,
      title: 'Request erasure?',
      message: _erasureWarning,
      confirmLabel: 'Confirm with Google',
    );

    if (confirmed) {
      await controller.requestErasureWithGoogle();
    }
  }
}

const String _erasureWarning =
    'Your account and the data held about it will be erased. This cannot be '
    'undone. Confirm that it is you to request it.';

/// Asks for the password that confirms an erasure request.
class _PasswordErasureDialog extends StatefulWidget {
  const _PasswordErasureDialog();

  @override
  State<_PasswordErasureDialog> createState() => _PasswordErasureDialogState();
}

class _PasswordErasureDialogState extends State<_PasswordErasureDialog> {
  final _password = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (_password.text.isNotEmpty) {
      Navigator.of(context).pop(_password.text);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Request erasure?'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(_erasureWarning),
        const SizedBox(height: 16),
        TextField(
          controller: _password,
          autofocus: true,
          obscureText: true,
          autofillHints: const <String>[AutofillHints.password],
          decoration: const InputDecoration(labelText: 'Password'),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _submit(),
        ),
      ],
    ),
    actions: <Widget>[
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _password.text.isEmpty ? null : _submit,
        child: const Text('Request erasure'),
      ),
    ],
  );
}

/// Confirms an erasure request with Google's own button, on the web.
class _GoogleErasureDialog extends ConsumerStatefulWidget {
  const _GoogleErasureDialog();

  @override
  ConsumerState<_GoogleErasureDialog> createState() =>
      _GoogleErasureDialogState();
}

class _GoogleErasureDialogState extends ConsumerState<_GoogleErasureDialog> {
  StreamSubscription<GoogleIdTokenObtained>? _tokens;

  @override
  void initState() {
    super.initState();

    final gateway = ref.read(googleSignInGatewayProvider);

    unawaited(gateway.initialize());
    _tokens = gateway.idTokens.listen((obtained) {
      if (mounted) {
        Navigator.of(context).pop(obtained.idToken);
      }
    });
  }

  @override
  void dispose() {
    unawaited(_tokens?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Request erasure?'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(_erasureWarning),
        const SizedBox(height: 16),
        buildPlatformGoogleButton(),
      ],
    ),
    actions: <Widget>[
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
    ],
  );
}

/// What went well, said plainly. Not an error banner: nothing went wrong.
class _Notice extends StatelessWidget {
  const _Notice(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // A live region, so a screen reader announces the outcome when it appears.
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.secondaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          message,
          style: TextStyle(color: scheme.onSecondaryContainer),
        ),
      ),
    );
  }
}

/// A button's label, or a spinner in its place while its request is in flight.
class _Label extends StatelessWidget {
  const _Label(this.text, {required this.busy});

  final String text;
  final bool busy;

  @override
  Widget build(BuildContext context) => busy
      ? Semantics(
          label: text,
          child: const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        )
      : Text(text);
}
