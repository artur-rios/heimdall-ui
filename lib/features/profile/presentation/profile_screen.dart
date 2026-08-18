import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/result/result.dart';
import '../../../shared/layout/app_shell.dart';
import '../../../shared/widgets/failure_banner.dart';
import '../../auth/presentation/email_verification_controller.dart';
import '../../home/presentation/home_screen.dart';
import '../../persons/domain/person.dart';
import 'profile_controller.dart';

/// UI-08 — the signed-in person's own profile.
///
/// Read and edit in one screen: the record is what the API returned, and the
/// form starts from it, so there is never a version of the person on screen
/// that the API has not confirmed.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();

  /// The record the fields were last seeded from, which is what AF-08d
  /// compares against to decide whether anything actually differs.
  Person? _seeded;

  @override
  void initState() {
    super.initState();
    // The read happens once the first frame is scheduled, so the controller is
    // never written to during a build.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(profileControllerProvider.notifier).load(),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  /// Copies a freshly loaded or freshly saved record into the fields.
  ///
  /// AF-08b is why this only runs when the record itself changed: a refused
  /// save must leave what the user typed exactly where it was.
  void _seed(Person person) {
    if (identical(_seeded, person)) {
      return;
    }

    _seeded = person;
    _name.text = person.name;
    _email.text = person.email;
  }

  bool _differsFrom(Person person) =>
      _name.text.trim() != person.name || _email.text.trim() != person.email;

  Future<void> _save() async {
    // AF-08a: an empty name or a malformed address never reaches the API.
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    await ref
        .read(profileControllerProvider.notifier)
        .save(name: _name.text.trim(), email: _email.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(profileControllerProvider);

    // AF-08e: the session is already gone, so the shell has no navigation to
    // draw and would show a spinner over the explanation the user is owed.
    if (state case ProfileUnavailable(sessionEnded: true, :final failure)) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: _Unavailable(failure: failure, sessionEnded: true),
      );
    }

    return AppShell(
      currentRoute: '/profile',
      title: const Text('Profile'),
      body: switch (state) {
        ProfileLoading() => const Center(child: CircularProgressIndicator()),
        ProfileUnavailable(:final failure, :final sessionEnded) => _Unavailable(
          failure: failure,
          sessionEnded: sessionEnded,
        ),
        final ProfileLoaded loaded => _form(loaded),
      },
    );
  }

  Widget _form(ProfileLoaded state) {
    final theme = Theme.of(context);
    _seed(state.person);
    final person = state.person;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Form(
            key: _formKey,
            // Every keystroke re-evaluates whether anything differs, which is
            // what keeps the save control honest about AF-08d.
            onChanged: () => setState(() {}),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text('Your details', style: theme.textTheme.headlineSmall),
                const SizedBox(height: 16),
                _Facts(person: person),
                const SizedBox(height: 24),
                if (state.saveFailure != null) ...<Widget>[
                  if (state.saveFailure!.kind == FailureKind.network)
                    RetryBanner(onRetry: state.saving ? null : _save)
                  else
                    // AF-08b: the API's strings, as returned.
                    ErrorBanner(failure: state.saveFailure!),
                  const SizedBox(height: 16),
                ],
                if (state.saved) ...<Widget>[
                  _SaveConfirmation(emailChanged: state.emailChanged),
                  const SizedBox(height: 16),
                ],
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (value) => (value?.trim().isEmpty ?? true)
                      ? 'Enter your name.'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                  onFieldSubmitted: (_) => _save(),
                  validator: (value) {
                    final email = value?.trim() ?? '';

                    if (email.isEmpty) {
                      return 'Enter your email address.';
                    }

                    return email.contains('@')
                        ? null
                        : 'Enter a valid email address.';
                  },
                ),
                const SizedBox(height: 24),
                FilledButton(
                  // AF-08d: nothing to save is not an action.
                  onPressed: (state.saving || !_differsFrom(person))
                      ? null
                      : _save,
                  child: state.saving
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save changes'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// What the API knows about the person that they cannot edit here.
class _Facts extends StatelessWidget {
  const _Facts({required this.person});

  final Person person;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: DefaultTextStyle.merge(
          style: theme.textTheme.bodyMedium,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _Fact(label: 'Role', value: roleLabel(person.role)),
              _Fact(
                label: 'Email verified',
                value: person.emailVerified ? 'Yes' : 'No',
              ),
              _Fact(
                label: 'Scope',
                value: person.scopeId ?? 'Not a member of a scope',
              ),
              if (person.ownedScopeIds.isNotEmpty)
                _Fact(
                  label: 'Owned scopes',
                  value: person.ownedScopeIds.join(', '),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 140,
          child: Text(label, style: Theme.of(context).textTheme.labelLarge),
        ),
        Expanded(child: Text(value)),
      ],
    ),
  );
}

/// What a successful save says — and, when the address changed, the resend
/// AF-08c owes the user.
class _SaveConfirmation extends ConsumerWidget {
  const _SaveConfirmation({required this.emailChanged});

  final bool emailChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final resend = ref.watch(emailVerificationControllerProvider).resend;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            emailChanged
                // AF-08c: the API marks a changed address unverified again, so
                // saying only "saved" would leave the user to discover it.
                ? 'Saved. Your new address is not verified yet, so we need to '
                      'confirm it before it can be used.'
                : 'Saved.',
            style: TextStyle(color: scheme.onSecondaryContainer),
          ),
          if (emailChanged) ...<Widget>[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: switch (resend) {
                ResendSent() => Text(
                  'A verification email is on its way.',
                  style: TextStyle(color: scheme.onSecondaryContainer),
                ),
                _ => TextButton(
                  onPressed: resend is Resending
                      ? null
                      : () => ref
                            .read(emailVerificationControllerProvider.notifier)
                            .resend(),
                  child: const Text('Send verification email'),
                ),
              },
            ),
          ],
        ],
      ),
    );
  }
}

/// The record could not be read.
///
/// AF-08e is the one case worth its own wording: the session has already been
/// ended, and the user is owed the reason rather than a bare sign-in screen.
class _Unavailable extends StatelessWidget {
  const _Unavailable({required this.failure, required this.sessionEnded});

  final Failure failure;
  final bool sessionEnded;

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
              Icon(
                sessionEnded ? Icons.person_off_outlined : Icons.error_outline,
                size: 48,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                sessionEnded
                    ? 'Your account no longer exists'
                    : 'Could not load your profile',
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              if (sessionEnded)
                Text(
                  'The account this session belonged to has been removed, so '
                  'you have been signed out.',
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                )
              else
                ErrorBanner(failure: failure),
            ],
          ),
        ),
      ),
    );
  }
}
