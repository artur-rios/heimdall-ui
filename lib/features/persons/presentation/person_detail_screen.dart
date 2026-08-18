import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/result/result.dart';
import '../../../shared/layout/app_shell.dart';
import '../../../shared/widgets/collection_states.dart';
import '../../../shared/widgets/failure_banner.dart';
import '../../auth/domain/session.dart';
import '../../auth/presentation/session_controller.dart';
import '../../home/presentation/home_screen.dart';
import '../domain/person.dart';
import 'person_detail_controller.dart';

/// UI-18 — one person, as an administrator sees them.
class PersonDetailScreen extends ConsumerStatefulWidget {
  const PersonDetailScreen({
    required this.scopeId,
    required this.personId,
    super.key,
  });

  final String scopeId;
  final String personId;

  @override
  ConsumerState<PersonDetailScreen> createState() => _PersonDetailScreenState();
}

class _PersonDetailScreenState extends ConsumerState<PersonDetailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();

  /// The record the fields were last seeded from, which is what decides
  /// whether anything actually differs.
  Person? _seeded;

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
    _name.text = person.name;
    _email.text = person.email;
  }

  bool _differsFrom(Person person) =>
      _name.text.trim() != person.name || _email.text.trim() != person.email;

  /// AF-18e — whether this is the caller's own record, which is worth saying
  /// out loud on an administrative screen.
  bool get _isSelf {
    final session = ref.watch(sessionControllerProvider);

    return session is Authenticated && session.principal.id == widget.personId;
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
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
    final backToListing = '/scopes/${widget.scopeId}/persons';

    return AppShell(
      currentRoute: '/scopes',
      title: Text(switch (state) {
        PersonDetailLoaded(:final person) => person.name,
        _ => 'Person',
      }),
      actions: <Widget>[
        IconButton(
          tooltip: 'Back to the listing',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(backToListing),
        ),
      ],
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
          actionLabel: 'Back to the listing',
          onAction: () => context.go(backToListing),
        ),
        // AF-18b — the API says this person is not within reach of this role.
        PersonDetailUnavailable(isForbidden: true) => CollectionEmpty(
          title: 'Not available for your role',
          message:
              'This person is not one you administer. Nothing is wrong '
              'with your session.',
          icon: Icons.lock_person_outlined,
          actionLabel: 'Back to the listing',
          onAction: () => context.go(backToListing),
        ),
        PersonDetailUnavailable(:final failure) => CollectionFailed(
          failure: failure,
          onRetry: controller.load,
        ),
        final PersonDetailLoaded loaded => _detail(loaded),
      },
    );
  }

  Widget _detail(PersonDetailLoaded state) {
    final theme = Theme.of(context);
    _seed(state.person);
    final person = state.person;

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
                const _Notice(
                  icon: Icons.person_off_outlined,
                  message:
                      'This person is deleted. They are shown for '
                      'reference and cannot be changed from here.',
                  destructive: true,
                ),
                const SizedBox(height: 16),
              ],
              // AF-18e — this is you. The editing is the same as UI-08's, and
              // the role is not editable here for anyone.
              if (_isSelf && !state.isReadOnly) ...<Widget>[
                const _Notice(
                  icon: Icons.person_outline,
                  message:
                      'This is your own record. Your role is not '
                      'something you can change here.',
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
                      const _Notice(
                        icon: Icons.check_circle_outline,
                        message: 'Saved.',
                      ),
                      const SizedBox(height: 16),
                    ],
                    TextFormField(
                      controller: _name,
                      readOnly: state.isReadOnly,
                      decoration: const InputDecoration(labelText: 'Name'),
                      validator: (value) => (value?.trim().isEmpty ?? true)
                          ? 'Enter a name.'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _email,
                      readOnly: state.isReadOnly,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Email'),
                      validator: (value) {
                        final email = value?.trim() ?? '';

                        if (email.isEmpty) {
                          return 'Enter an email address.';
                        }

                        return email.contains('@')
                            ? null
                            : 'Enter a valid email address.';
                      },
                    ),
                    const SizedBox(height: 16),
                    if (!state.isReadOnly)
                      FilledButton(
                        onPressed: (state.saving || !_differsFrom(person))
                            ? null
                            : _save,
                        child: state.saving
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Save changes'),
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
            ],
          ),
        ),
      ),
    );
  }
}

/// A one-line panel: what a deleted record, your own record, and a saved edit
/// each say about themselves.
class _Notice extends StatelessWidget {
  const _Notice({
    required this.icon,
    required this.message,
    this.destructive = false,
  });

  final IconData icon;
  final String message;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = destructive
        ? scheme.errorContainer
        : scheme.secondaryContainer;
    final foreground = destructive
        ? scheme.onErrorContainer
        : scheme.onSecondaryContainer;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, color: foreground),
          const SizedBox(width: 12),
          Expanded(
            child: Text(message, style: TextStyle(color: foreground)),
          ),
        ],
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
