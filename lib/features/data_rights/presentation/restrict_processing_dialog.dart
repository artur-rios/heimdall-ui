import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/result/result.dart';
import '../../../shared/widgets/failure_banner.dart';
import '../domain/data_rights.dart';
import 'restrict_processing_controller.dart';

/// UI-33 — asks the signed-in person why they want processing of their account
/// restricted, says what that does, and asks the API.
///
/// On success the controller signs the person out, and the dialog closes
/// before the route guard replaces the page beneath it.
Future<void> showRestrictProcessingDialog(BuildContext context) =>
    showDialog<void>(
      context: context,
      builder: (context) => const _RestrictProcessingDialog(),
    );

/// The ground in the person's own words: GDPR Art. 18(1) as they would say it.
({String title, String detail}) _wording(
  RestrictionGround ground,
) => switch (ground) {
  RestrictionGround.accuracyContested => (
    title: 'I believe my data is inaccurate',
    detail: 'Keep it unused while its accuracy is checked.',
  ),
  RestrictionGround.unlawfulButErasureOpposed => (
    title: 'My data is being processed unlawfully, but I do not want it erased',
    detail: 'Keep it, unused, rather than erasing it.',
  ),
  RestrictionGround.neededForLegalClaim => (
    title:
        'Heimdall no longer needs my data, but I need it kept for a legal '
        'claim',
    detail: 'Keep it so I can establish, exercise or defend the claim.',
  ),
  RestrictionGround.objectionPending => (
    title: 'I have objected to Heimdall processing my data',
    detail: 'Keep it unused while my objection is considered.',
  ),
};

class _RestrictProcessingDialog extends ConsumerWidget {
  const _RestrictProcessingDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(restrictProcessingControllerProvider);
    final controller = ref.read(restrictProcessingControllerProvider.notifier);

    // A request in flight cannot be walked away from: the dialog is the only
    // place its outcome is shown.
    return PopScope(
      canPop: !state.sending,
      child: AlertDialog(
        // Scrolls rather than overflowing on a short window.
        scrollable: true,
        title: const Text('Restrict processing of your account?'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'While processing is restricted, Heimdall keeps your data '
                'exactly as it is and uses it for nothing else, and your '
                'account is suspended until the restriction is lifted. You '
                'will be signed out now.',
              ),
              const SizedBox(height: 8),
              const Text(
                'You can still sign in to lift the restriction, or to '
                'download or erase your data.',
              ),
              const SizedBox(height: 16),
              Semantics(
                header: true,
                child: Text(
                  'Why are you asking for it?',
                  style: theme.textTheme.titleSmall,
                ),
              ),
              const SizedBox(height: 4),
              RadioGroup<RestrictionGround>(
                groupValue: state.ground,
                onChanged: (ground) {
                  if (ground != null) {
                    controller.choose(ground);
                  }
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    for (final ground in RestrictionGround.values)
                      RadioListTile<RestrictionGround>(
                        value: ground,
                        enabled: !state.sending,
                        contentPadding: EdgeInsets.zero,
                        title: Text(_wording(ground).title),
                        subtitle: Text(_wording(ground).detail),
                      ),
                  ],
                ),
              ),
              if (state.sending) ...<Widget>[
                const SizedBox(height: 16),
                const LinearProgressIndicator(
                  semanticsLabel: 'Restricting processing',
                ),
              ],
              if (state.failure case final Failure failure) ...<Widget>[
                const SizedBox(height: 16),
                // AF-33b / AF-33c: the API's own words, as returned.
                ErrorBanner(failure: _shown(failure)),
              ],
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            // AF-33a: closing sends nothing.
            onPressed: state.sending ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: state.canConfirm
                ? () => _restrict(context, controller)
                : null,
            child: const Text('Restrict processing'),
          ),
        ],
      ),
    );
  }

  Future<void> _restrict(
    BuildContext context,
    RestrictProcessingController controller,
  ) async {
    final navigator = Navigator.of(context);

    // On success the session has ended by now, and the route guard is about
    // to replace the page beneath: the dialog goes first.
    if (await controller.restrict() && context.mounted) {
      navigator.pop();
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
}
