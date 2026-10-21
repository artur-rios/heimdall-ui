import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/result/result.dart';
import '../../../shared/forms/edit_mode.dart';
import '../../../shared/forms/field_rules.dart';
import '../../../shared/forms/form_feedback.dart';
import '../../../shared/layout/app_shell.dart';
import '../../../shared/widgets/collection_states.dart';
import '../../../shared/widgets/delete_actions.dart';
import '../../../shared/widgets/failure_banner.dart';
import '../../../shared/widgets/notice.dart';
import '../../auth/domain/session.dart';
import '../../auth/presentation/session_controller.dart';
import '../../home/presentation/home_screen.dart';
import '../domain/person.dart';
import 'account_emails_card.dart';
import 'person_detail_controller.dart';

/// UI-18 — one person, as an administrator sees them.
class PersonDetailScreen extends ConsumerStatefulWidget {
  const PersonDetailScreen({required this.personId, this.scopeId, super.key});

  /// The scope the person was reached through, or `null` when they were
  /// opened from the System Admins list (UI-38), which has no scope.
  final String? scopeId;
  final String personId;

  @override
  ConsumerState<PersonDetailScreen> createState() => _PersonDetailScreenState();
}

class _PersonDetailScreenState extends ConsumerState<PersonDetailScreen> {
  var _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();

  /// The record the fields were last seeded from, which is what decides
  /// whether anything actually differs.
  Person? _seeded;

  /// Whether the person has asked to change the record. The fields are
  /// read-only until they do, and again once the change is saved or dropped.
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref
          .read(personDetailControllerProvider(widget.personId).notifier)
          .load(),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  /// Copies a freshly read or freshly saved record into the fields.
  ///
  /// AF-18c is why this only runs when the record itself changed: a refused
  /// save must leave what the user typed exactly where it was.
  void _seed(Person person) {
    if (identical(_seeded, person)) {
      return;
    }

    _seeded = person;

    // A background reload (AF-36c) can land mid-edit; what was typed and not
    // yet saved stays. `_seeded` still moves on, so the leave guard compares
    // the typing against the record the API now holds.
    if (!_editing) {
      _restore(person);
    }
  }

  void _restore(Person person) {
    _name.text = person.name;
    _email.text = person.email;
  }

  void _startEditing() {
    ref
        .read(personDetailControllerProvider(widget.personId).notifier)
        .acknowledgeSave();
    setState(() => _editing = true);
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
    ref
        .read(personDetailControllerProvider(widget.personId).notifier)
        .acknowledgeSave();
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

  /// AF-18e — whether this is the caller's own record, which is worth saying
  /// out loud on an administrative screen.
  bool get _isSelf {
    final session = ref.watch(sessionControllerProvider);

    return session is Authenticated && session.principal.id == widget.personId;
  }

  /// AF-19e — only a System Admin erases a person permanently.
  bool get _maySeeHardDelete {
    final session = ref.watch(sessionControllerProvider);

    return session is Authenticated && session.principal.isSystemAdmin;
  }

  /// Whether the API would take an update to [person] from the caller: a
  /// System Admin may update anyone, anybody may update themselves, and a
  /// Scope Admin may update the Users of a scope they own — never a co-owner
  /// they can see but not change (UC-08's `NotAuthorizedToUpdatePerson`).
  bool _mayUpdate(Person person) =>
      _maySeeHardDelete || _isSelf || person.role == Role.user;

  /// Whether the API would take a logical delete of [person] from the caller:
  /// a System Admin, or a Scope Admin deleting a User (UC-09's
  /// `NotAuthorizedToDeletePerson`).
  bool _mayDelete(Person person) =>
      _maySeeHardDelete || person.role == Role.user;

  /// UC-51/UC-52: a System Admin for anyone, a Scope Admin for the Users of
  /// scopes they own. The API decides the ownership; this only decides what
  /// is offered.
  bool _mayEmail(Person person) =>
      _maySeeHardDelete || person.role == Role.user;

  Future<void> _save() async {
    if (!validateAndReveal(_formKey)) {
      return;
    }

    await ref
        .read(personDetailControllerProvider(widget.personId).notifier)
        .save(name: _name.text.trim(), email: _email.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(personDetailControllerProvider(widget.personId));
    final controller = ref.read(
      personDetailControllerProvider(widget.personId).notifier,
    );
    final scopeId = widget.scopeId;
    final backToListing = scopeId == null
        ? '/system-admins'
        : '/scopes/$scopeId/persons';
    final backTooltip = scopeId == null
        ? 'Back to System Admins'
        : 'Back to the listing';

    // A deleted person returns to the listing, which reads itself again.
    ref.listen<PersonDetailState>(
      personDetailControllerProvider(widget.personId),
      (previous, next) {
        // A save that went through ends the edit.
        if (previous is PersonDetailLoaded &&
            previous.saving &&
            next is PersonDetailLoaded &&
            next.saved) {
          setState(() => _editing = false);
        }

        if (next is PersonDeleted) {
          // The edit went with the record, so leaving has nothing to ask.
          setState(() => _editing = false);
          context.go(backToListing);
        }
      },
    );

    return AppShell(
      currentRoute: scopeId == null ? '/' : '/scopes',
      title: Text(switch (state) {
        PersonDetailLoaded(:final person) => person.name,
        _ => 'Person',
      }),
      hasUnsavedChanges: () => _hasUnsavedEdit,
      backRoute: backToListing,
      backTooltip: backTooltip,
      body: switch (state) {
        PersonDetailLoading() => const Center(
          child: CircularProgressIndicator(),
        ),
        // AF-18a — no such person.
        PersonDetailUnavailable(isNotFound: true) => CollectionEmpty(
          title: 'Person not found',
          message:
              'There is nobody with that identifier. They may have been '
              'permanently deleted.',
          icon: Icons.search_off_outlined,
          actionLabel: backTooltip,
          onAction: () => context.go(backToListing),
        ),
        // AF-18b — the API says this person is not within reach of this role.
        PersonDetailUnavailable(isForbidden: true) => CollectionEmpty(
          title: 'Not available for your role',
          message:
              'This person is not one you administer. Nothing is wrong '
              'with your session.',
          icon: Icons.lock_person_outlined,
          actionLabel: backTooltip,
          onAction: () => context.go(backToListing),
        ),
        PersonDetailUnavailable(:final failure) => CollectionFailed(
          failure: failure,
          onRetry: controller.load,
        ),
        // The listing is where a deleted person leaves the user; this is the
        // frame in between.
        PersonDeleted() => const Center(child: CircularProgressIndicator()),
        final PersonDetailLoaded loaded => _detail(loaded),
      },
    );
  }

  Widget _detail(PersonDetailLoaded state) {
    final theme = Theme.of(context);
    _seed(state.person);
    final person = state.person;
    final mayEdit = !state.isReadOnly && _mayUpdate(person);
    final editing = _editing && mayEdit;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // AF-18d — a deleted person says so before anything else, since
              // everything below is read-only because of it.
              if (state.isReadOnly) ...<Widget>[
                const Notice(
                  'This person is deleted. They are shown for '
                  'reference and cannot be changed from here.',
                  icon: Icons.person_off_outlined,
                  isError: true,
                ),
                const SizedBox(height: 16),
              ],
              // AF-18e — this is you. The editing is the same as UI-08's, and
              // the role is not editable here for anyone.
              if (_isSelf && !state.isReadOnly) ...<Widget>[
                const Notice(
                  'This is your own record. Your role is not '
                  'something you can change here. Change your email '
                  'address from your profile.',
                  icon: Icons.person_outline,
                ),
                const SizedBox(height: 16),
              ],
              Form(
                key: _formKey,
                onChanged: () => setState(() {}),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    if (state.saveFailure
                        case final Failure failure) ...<Widget>[
                      if (failure.kind == FailureKind.network)
                        RetryBanner(onRetry: state.saving ? null : _save)
                      else
                        // AF-18c: the API's own strings, as returned.
                        ErrorBanner(failure: failure),
                      const SizedBox(height: 16),
                    ],
                    if (state.saved) ...<Widget>[
                      const Notice('Saved.', icon: Icons.check_circle_outline),
                      const SizedBox(height: 16),
                    ],
                    EditableSection(
                      title: 'Details',
                      editing: editing,
                      mayEdit: mayEdit,
                      saving: state.saving,
                      canSave: _differsFrom(person) && !state.deleting,
                      onEdit: _startEditing,
                      onCancel: _cancelEditing,
                      onSave: _save,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          TextFormField(
                            maxLength: nameMaxLength,
                            controller: _name,
                            readOnly: !editing,
                            decoration: recordFieldDecoration(
                              context,
                              label: 'Name',
                              editing: editing,
                            ),
                            validator: (value) =>
                                (value?.trim().isEmpty ?? true)
                                ? 'Enter a name.'
                                : null,
                          ),
                          const SizedBox(height: 16),
                          // FR-AU-16: your own address is changed from your
                          // profile, which asks for your password and signs
                          // you in again; this screen asks for neither.
                          TextFormField(
                            controller: _email,
                            readOnly: !editing || _isSelf,
                            keyboardType: TextInputType.emailAddress,
                            decoration:
                                recordFieldDecoration(
                                  context,
                                  label: 'Email',
                                  editing: editing && !_isSelf,
                                ).copyWith(
                                  helperText: editing && _isSelf
                                      ? 'Change your own email from your '
                                            'profile.'
                                      : null,
                                ),
                            validator: (value) {
                              final email = value?.trim() ?? '';

                              if (email.isEmpty) {
                                return 'Enter an email address.';
                              }

                              return isPlausibleEmail(email)
                                  ? null
                                  : 'Enter a valid email address.';
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Card(
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
                          label: 'Two-factor authentication',
                          value: person.twoFactorEnabled ? 'On' : 'Off',
                        ),
                        _Fact(
                          label: 'Scope',
                          value: person.scopeId ?? 'Not a member of a scope',
                        ),
                        _Fact(
                          label: 'Owned scopes',
                          value: person.ownedScopeIds.isEmpty
                              ? 'None'
                              : person.ownedScopeIds.join(', '),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // UI-36 — people use the profile screen for their own account,
              // and a deleted person has no account left to email.
              if (!state.isReadOnly &&
                  !_isSelf &&
                  _mayEmail(person)) ...<Widget>[
                const SizedBox(height: 24),
                AccountEmailsCard(
                  person: person,
                  onVerificationRefused: () => ref
                      .read(
                        personDetailControllerProvider(widget.personId)
                            .notifier,
                      )
                      .refresh(),
                ),
              ],
              // AF-19d — the controls are disabled on your own record, and
              // AF-18d leaves a deleted person nothing left to delete.
              if (!state.isReadOnly && _mayDelete(person)) ...<Widget>[
                const SizedBox(height: 24),
                DeleteActions(
                  recordName: person.name,
                  noun: 'person',
                  confirmationValue: person.email,
                  fieldLabel: 'Email address',
                  permanentConsequence:
                      'Their record, the applications they own, their tokens, '
                      'and their scope membership are all erased.',
                  anonymises: true,
                  deleting: state.deleting || state.saving,
                  failure: state.deleteFailure,
                  // AF-19d: you cannot delete yourself from here. The API
                  // refuses it too; this stops the interface offering it.
                  blockedReason: _isSelf
                      ? 'You cannot delete your own account from here.'
                      : null,
                  // AF-19e: a Scope Admin never sees the permanent deletion.
                  mayDeletePermanently: _maySeeHardDelete,
                  onDelete: () => ref
                      .read(
                        personDetailControllerProvider(widget.personId)
                            .notifier,
                      )
                      .delete(),
                  onDeletePermanently: () => ref
                      .read(
                        personDetailControllerProvider(widget.personId)
                            .notifier,
                      )
                      .deletePermanently(),
                ),
              ],
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
