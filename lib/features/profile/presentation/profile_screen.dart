import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/result/result.dart';
import '../../../shared/forms/edit_mode.dart';
import '../../../shared/forms/field_rules.dart';
import '../../../shared/forms/form_feedback.dart';
import '../../../shared/layout/app_shell.dart';
import '../../../shared/widgets/failure_banner.dart';
import '../../../shared/widgets/notice.dart';
import '../../auth/domain/two_factor.dart';
import '../../data_rights/presentation/restrict_processing_dialog.dart';
import '../../google_users/domain/google_user.dart';
import '../../google_users/presentation/google_avatar.dart';
import '../../home/presentation/home_screen.dart';
import '../../persons/domain/person.dart';
import 'profile_controller.dart';

/// UI-08 — the signed-in person's own profile.
///
/// Read and edit in one screen: the record is what the API returned, and the
/// form starts from it, so there is never a version of the person on screen
/// that the API has not confirmed. The fields stay read-only until **Edit** is
/// pressed. A Google User's record is read-only throughout: Google owns it.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  var _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();

  /// FR-AU-16 — what a change of address is confirmed with. Asked for only
  /// while the address differs, and cleared whenever the edit ends.
  final _currentPassword = TextEditingController();
  final _twoFactorCode = TextEditingController();

  /// The record the fields were last seeded from, which is what AF-08d
  /// compares against to decide whether anything actually differs.
  Person? _seeded;

  /// Whether the person has asked to change their details. The fields are
  /// read-only until they do, and again once the change is saved or dropped.
  bool _editing = false;

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
    _currentPassword.dispose();
    _twoFactorCode.dispose();
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
    _restore(person);
  }

  void _restore(Person person) {
    _name.text = person.name;
    _email.text = person.email;
    _forgetReauthentication();
  }

  /// A password or code typed for one edit never waits in the form for the
  /// next.
  void _forgetReauthentication() {
    _currentPassword.clear();
    _twoFactorCode.clear();
  }

  void _startEditing() {
    final controller = ref.read(profileControllerProvider.notifier)
      ..acknowledgeSave();
    setState(() => _editing = true);
    // FR-AU-16: which second factor is on decides what a new address's code
    // field suggests, so it is read before one can be typed.
    controller.readSecondFactor();
  }

  /// Leaving with unsaved changes — by the navigation, the back control, a
  /// system or browser Back, or signing out — asks first (`AppShell`).
  bool get _hasUnsavedEdit {
    final seeded = _seeded;

    return _editing && seeded != null && _differsFrom(seeded);
  }

  /// Puts back what the API holds and leaves edit mode, dropping any refusal
  /// along with the edit it was about.
  void _cancelEditing() {
    ref.read(profileControllerProvider.notifier).acknowledgeSave();
    setState(() {
      _editing = false;
      // A fresh key forgets the fields' validation messages too.
      _formKey = GlobalKey<FormState>();

      if (_seeded case final person?) {
        _restore(person);
      }
    });
  }

  bool _differsFrom(Person person) =>
      _name.text.trim() != person.name || _email.text.trim() != person.email;

  /// FR-AU-16 — whether the edit changes the address, which is what asks for
  /// the password (and the second factor, when it is on).
  bool _changesEmail(Person person) =>
      _editing && changesEmail(person, _email.text.trim());

  /// AF-08i — opens the two-factor settings, where the email method is turned
  /// off, once any unsaved edit has been let go.
  ///
  /// Security sits over this route rather than leaving it, so its `onExit`
  /// does not ask; this does, and lets the edit go before opening it.
  Future<void> _openSecurity() async {
    if (!await confirmDiscardChanges(context, hasChanges: _hasUnsavedEdit) ||
        !mounted) {
      return;
    }

    if (_editing) {
      _cancelEditing();
    }

    context.go('/profile/security');
  }

  Future<void> _save() async {
    // AF-08a: an empty name or a malformed address never reaches the API, and
    // nor does a new address without the password it needs.
    if (!validateAndReveal(_formKey)) {
      return;
    }

    await ref
        .read(profileControllerProvider.notifier)
        .save(
          name: _name.text.trim(),
          email: _email.text.trim(),
          currentPassword: _currentPassword.text,
          twoFactorCode: _twoFactorCode.text.trim(),
        );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(profileControllerProvider);

    // A save that went through ends the edit.
    ref.listen<ProfileState>(profileControllerProvider, (previous, next) {
      if (previous is ProfileLoaded &&
          previous.saving &&
          next is ProfileLoaded &&
          next.saved) {
        setState(() => _editing = false);
      }
    });

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
      hasUnsavedChanges: () => _hasUnsavedEdit,
      // Back from Security, where the second factor may have changed. An
      // edit in progress is not read over.
      onReturn: () {
        if (!_editing) {
          ref.read(profileControllerProvider.notifier).load();
        }
      },
      body: switch (state) {
        ProfileLoading() => const Center(child: CircularProgressIndicator()),
        ProfileUnavailable(:final failure, :final sessionEnded) => _Unavailable(
          failure: failure,
          sessionEnded: sessionEnded,
        ),
        final ProfileLoaded loaded => _form(loaded),
        GoogleProfileLoaded(:final user) => _GoogleProfile(user: user),
      },
    );
  }

  Widget _form(ProfileLoaded state) {
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
                if (state.saveFailure != null) ...<Widget>[
                  if (state.saveFailure!.kind == FailureKind.network)
                    RetryBanner(onRetry: state.saving ? null : _save)
                  else
                    // AF-08b: the API's strings, as returned.
                    ErrorBanner(failure: state.saveFailure!),
                  // AF-08i: the way out of the refusal is somewhere else.
                  if (_blocksEmailChange(state.saveFailure!))
                    _EmailMethodHint(onOpen: _openSecurity),
                  const SizedBox(height: 16),
                ],
                if (state.saved) ...<Widget>[
                  // A change of address never stays here to be told: it signs the
                  // person out (FR-AU-28), and the sign-in that follows reports
                  // the address unverified and offers the resend (AF-05e).
                  const Notice('Saved.'),
                  const SizedBox(height: 16),
                ],
                EditableSection(
                  title: 'Your details',
                  editing: _editing,
                  mayEdit: true,
                  saving: state.saving,
                  // AF-08d: nothing to save is not an action.
                  canSave: _differsFrom(person),
                  onEdit: _startEditing,
                  onCancel: _cancelEditing,
                  onSave: _save,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      TextFormField(
                        maxLength: nameMaxLength,
                        controller: _name,
                        readOnly: !_editing,
                        decoration: recordFieldDecoration(
                          context,
                          label: 'Name',
                          editing: _editing,
                        ),
                        validator: (value) => (value?.trim().isEmpty ?? true)
                            ? 'Enter your name.'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _email,
                        readOnly: !_editing,
                        keyboardType: TextInputType.emailAddress,
                        decoration: recordFieldDecoration(
                          context,
                          label: 'Email',
                          editing: _editing,
                        ),
                        onFieldSubmitted: _editing ? (_) => _save() : null,
                        validator: (value) {
                          final email = value?.trim() ?? '';

                          if (email.isEmpty) {
                            return 'Enter your email address.';
                          }

                          return isPlausibleEmail(email)
                              ? null
                              : 'Enter a valid email address.';
                        },
                      ),
                      if (_changesEmail(person))
                        _Reauthentication(
                          password: _currentPassword,
                          code: _twoFactorCode,
                          secondFactorOn: person.twoFactorEnabled,
                          secondFactor: state.secondFactor,
                          secondFactorKnown: state.secondFactorSettled,
                          onSubmitted: _save,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _Facts(person: person),
                const SizedBox(height: 16),
                const _AccountEntries(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The entries a profile leads on to, whoever's profile it is.
class _AccountEntries extends StatelessWidget {
  const _AccountEntries();

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      // UI-09 lives on its own screen: two-factor setup has states of its own
      // that have no business interrupting an edit here. A Google User finds
      // there why it does not apply to them.
      Card(
        child: ListTile(
          leading: const Icon(Icons.shield_outlined),
          title: const Text('Security'),
          subtitle: const Text('Two-factor authentication and recovery codes.'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.go('/profile/security'),
        ),
      ),
      const SizedBox(height: 16),
      // UI-33 — the one data-subject right a full session asks for here; the
      // others are offered once processing is restricted (UI-30), which is
      // where this leads.
      Card(
        child: ListTile(
          leading: const Icon(Icons.pause_circle_outline),
          title: const Text('Restrict processing of my account'),
          subtitle: const Text(
            'Have Heimdall keep your data but stop using it. Your account is '
            'suspended until you lift the restriction.',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => showRestrictProcessingDialog(context),
        ),
      ),
    ],
  );
}

/// A Google User's own profile (#133).
///
/// Read-only: the name, the address and the picture come from Google, and the
/// API offers no way to change them, so there is no Edit and no resend. It
/// says why rather than leaving the absence of controls to be puzzled over.
class _GoogleProfile extends StatelessWidget {
  const _GoogleProfile({required this.user});

  final GoogleUser user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          // The picture, or the initials when there is none.
                          GoogleAvatar(user: user, radius: 28),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              'Your details',
                              style: theme.textTheme.titleMedium,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _ReadOnlyField(label: 'Name', value: user.name),
                      const SizedBox(height: 16),
                      _ReadOnlyField(label: 'Email', value: user.email),
                      const SizedBox(height: 12),
                      Text(
                        'Your name and email come from your Google account.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: DefaultTextStyle.merge(
                    style: theme.textTheme.bodyMedium,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const _Fact(label: 'Signs in with', value: 'Google'),
                        _Fact(
                          label: 'Email verified',
                          value: user.emailVerified ? 'Yes' : 'No',
                        ),
                        if (user.scopeId case final scopeId?)
                          _Fact(label: 'Scope', value: scopeId),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const _AccountEntries(),
            ],
          ),
        ),
      ),
    );
  }
}

/// A labelled value drawn like a record field in view mode, with no input
/// behind it: there is nothing to type into.
class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => InputDecorator(
    decoration: recordFieldDecoration(context, label: label, editing: false),
    child: Text(value),
  );
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

/// The API's refusal of a change to one's own address while the email
/// sign-in method is on, enabled or pending (AF-08i).
const String _emailMethodBlocksChange =
    'Turn off the email sign-in method before changing your email address.';

/// Whether [failure] is AF-08i's refusal, which the form answers with a way
/// to the two-factor settings.
bool _blocksEmailChange(Failure failure) =>
    failure.kind == FailureKind.conflict &&
    failure.errors.contains(_emailMethodBlocksChange);

/// AF-08i — where to turn the email method off, said under the refusal.
class _EmailMethodHint extends StatelessWidget {
  const _EmailMethodHint({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Turn the email method off in your security settings, change your '
          'address, then set the method up again at the new one.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        TextButton(
          onPressed: onOpen,
          child: const Text('Open security settings'),
        ),
      ],
    ),
  );
}

/// FR-AU-16 — what a change of the person's own address is confirmed with:
/// the current password, and a second-factor code when that is on.
///
/// The API sends no emailed code while the person is signed in, so the code
/// is one from an authenticator app or a recovery code; a person whose only
/// method is email is pointed at their recovery codes. Changing the address
/// signs them out to sign in again with it, which is said up front.
class _Reauthentication extends StatelessWidget {
  const _Reauthentication({
    required this.password,
    required this.code,
    required this.secondFactorOn,
    required this.secondFactor,
    required this.secondFactorKnown,
    required this.onSubmitted,
  });

  final TextEditingController password;
  final TextEditingController code;
  final bool secondFactorOn;
  final TwoFactorStatus? secondFactor;

  /// Whether the read of [secondFactor] has finished. Until it has, the code
  /// field suggests nothing rather than the wrong thing.
  final bool secondFactorKnown;
  final VoidCallback onSubmitted;

  bool get _emailOnly =>
      secondFactor != null &&
      secondFactor!.emailEnabled &&
      !secondFactor!.appEnabled;

  /// What the code field suggests: nothing until the method is known, then a
  /// recovery code for an email-only person, and both ways in otherwise — the
  /// method unreadable included.
  String? get _codeHint {
    if (!secondFactorKnown) {
      return null;
    }

    return _emailOnly
        ? 'Use one of your recovery codes.'
        : 'A code from your authenticator app, or a recovery code.';
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      const SizedBox(height: 16),
      Text(
        'Changing your email address signs you out. Confirm it is you, then '
        'sign in again with the new address.',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: password,
        obscureText: true,
        decoration: const InputDecoration(labelText: 'Current password'),
        onFieldSubmitted: secondFactorOn ? null : (_) => onSubmitted(),
        validator: (value) =>
            (value ?? '').isEmpty ? 'Enter your current password.' : null,
      ),
      if (secondFactorOn) ...<Widget>[
        const SizedBox(height: 16),
        // A recovery code is sent as typed, whatever its length, case,
        // hyphens or spaces; nothing on the keyboard may rewrite it.
        TextFormField(
          controller: code,
          autocorrect: false,
          enableSuggestions: false,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(
            labelText: 'Two-factor code',
            helperText: _codeHint,
            helperMaxLines: 2,
          ),
          onFieldSubmitted: (_) => onSubmitted(),
          validator: (value) => (value?.trim().isEmpty ?? true)
              ? 'Enter a code or a recovery code.'
              : null,
        ),
      ],
    ],
  );
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
