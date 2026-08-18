import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/layout/app_shell.dart';
import '../../../shared/widgets/collection_states.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/failure_banner.dart';
import '../../auth/domain/session.dart';
import '../../auth/presentation/session_controller.dart';
import '../../persons/domain/person.dart';
import 'scope_owners_controller.dart';

/// UI-14 — the owners of one scope, and the four ways the list changes.
class ScopeOwnersScreen extends ConsumerStatefulWidget {
  const ScopeOwnersScreen({required this.scopeId, super.key});

  final String scopeId;

  @override
  ConsumerState<ScopeOwnersScreen> createState() => _ScopeOwnersScreenState();
}

class _ScopeOwnersScreenState extends ConsumerState<ScopeOwnersScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref
          .read(scopeOwnersControllerProvider(widget.scopeId).notifier)
          .load(),
    );
  }

  ScopeOwnersController get _controller =>
      ref.read(scopeOwnersControllerProvider(widget.scopeId).notifier);

  /// Who is signed in, which AF-14f needs in order to warn them about
  /// themselves.
  String? get _signedInPersonId {
    final session = ref.watch(sessionControllerProvider);

    return session is Authenticated ? session.principal.id : null;
  }

  Future<void> _addExisting() async {
    final personId = await showDialog<String>(
      context: context,
      builder: (context) => const _AddOwnerDialog(),
    );

    if (personId != null && personId.isNotEmpty && mounted) {
      await _controller.addOwner(personId);
    }
  }

  Future<void> _createNew() async {
    final draft = await showDialog<_OwnerDraft>(
      context: context,
      builder: (context) => const _CreateOwnerDialog(),
    );

    if (draft != null && mounted) {
      await _controller.createOwner(
        name: draft.name,
        email: draft.email,
        password: draft.password,
      );
    }
  }

  /// AF-14e — the dialog closes and nothing is sent.
  Future<void> _promote(Person user) async {
    final confirmed = await showConfirm(
      context: context,
      title: 'Promote ${user.name}?',
      message:
          '${user.name} becomes a Scope Admin and a co-owner of this '
          'scope, and stops being one of its users.',
      confirmLabel: 'Promote',
    );

    if (confirmed && mounted) {
      await _controller.promote(user.id);
    }
  }

  Future<void> _remove(Person owner) async {
    // AF-14f — removing your own ownership is a different warning, because the
    // thing you lose is your own access.
    final isSelf = owner.id == _signedInPersonId;

    final confirmed = await showConfirm(
      context: context,
      title: isSelf ? 'Remove your own ownership?' : 'Remove ${owner.name}?',
      message: isSelf
          ? 'You will stop owning this scope and lose access to it. Another '
                'owner would have to add you back.'
          : '${owner.name} will stop owning this scope. Their account is not '
                'deleted.',
      confirmLabel: 'Remove',
    );

    if (confirmed && mounted) {
      await _controller.removeOwner(owner.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(scopeOwnersControllerProvider(widget.scopeId));

    return AppShell(
      currentRoute: '/scopes',
      title: const Text('Scope owners'),
      actions: <Widget>[
        IconButton(
          tooltip: 'Back to the scope',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/scopes/${widget.scopeId}'),
        ),
      ],
      body: switch (state) {
        ScopeOwnersLoading() => const CollectionLoading(rows: 4),
        ScopeOwnersUnavailable(:final failure) => CollectionFailed(
          failure: failure,
          onRetry: _controller.load,
        ),
        final ScopeOwnersLoaded loaded => _owners(loaded),
      },
    );
  }

  Widget _owners(ScopeOwnersLoaded state) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: <Widget>[
        // AF-14a to AF-14d: whatever the API refused, in its own words.
        if (state.failure case final failure?) ...<Widget>[
          ErrorBanner(failure: failure),
          const SizedBox(height: 16),
        ],
        // A Wrap rather than a Row: on a narrow window the heading and the two
        // controls do not fit on one line, and an overflowing header hides the
        // control that adds an owner.
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            Text('Owners', style: theme.textTheme.titleLarge),
            TextButton.icon(
              onPressed: state.busy ? null : _addExisting,
              icon: const Icon(Icons.person_add_alt),
              label: const Text('Add existing'),
            ),
            FilledButton.icon(
              onPressed: state.busy ? null : _createNew,
              icon: const Icon(Icons.person_add),
              label: const Text('Create owner'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (state.owners.isEmpty)
          const CollectionEmpty(
            title: 'No owners recorded',
            message: 'The API reports no owners for this scope.',
            icon: Icons.shield_outlined,
          )
        else
          Card(
            child: Column(
              children: <Widget>[
                for (final owner in state.owners)
                  ListTile(
                    leading: const Icon(Icons.shield_outlined),
                    title: Text(owner.name),
                    subtitle: Text(owner.email),
                    trailing: IconButton(
                      tooltip: state.canRemove
                          ? 'Remove owner'
                          : 'A scope must keep at least one owner',
                      icon: const Icon(Icons.person_remove_outlined),
                      // AF-14a: the only owner cannot be removed.
                      onPressed: (state.busy || !state.canRemove)
                          ? null
                          : () => _remove(owner),
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 24),
        Text('Promote a user', style: theme.textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          'A user of this scope can be promoted to Scope Admin, which makes '
          'them a co-owner.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
        if (state.promotable.isEmpty)
          const CollectionEmpty(
            title: 'Nobody to promote',
            message: 'This scope has no users who are not already owners.',
            icon: Icons.people_outline,
          )
        else
          Card(
            child: Column(
              children: <Widget>[
                for (final user in state.promotable)
                  ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: Text(user.name),
                    subtitle: Text(user.email),
                    trailing: TextButton(
                      onPressed: state.busy ? null : () => _promote(user),
                      child: const Text('Promote'),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Names an existing Scope Admin to add.
///
/// As in UI-11, the API publishes no listing of Scope Admins outside a scope,
/// so the identifier is typed and the API judges it (AF-14b, AF-14c).
class _AddOwnerDialog extends StatefulWidget {
  const _AddOwnerDialog();

  @override
  State<_AddOwnerDialog> createState() => _AddOwnerDialogState();
}

class _AddOwnerDialogState extends State<_AddOwnerDialog> {
  final _personId = TextEditingController();

  @override
  void dispose() {
    _personId.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Add an existing Scope Admin'),
    content: TextField(
      controller: _personId,
      autofocus: true,
      decoration: const InputDecoration(
        labelText: 'Person identifier',
        helperText: 'The person id of an existing Scope Admin.',
      ),
      onChanged: (_) => setState(() {}),
      onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
    ),
    actions: <Widget>[
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _personId.text.trim().isEmpty
            ? null
            : () => Navigator.of(context).pop(_personId.text.trim()),
        child: const Text('Add owner'),
      ),
    ],
  );
}

/// What the create-a-co-owner dialog collects.
class _OwnerDraft {
  const _OwnerDraft({
    required this.name,
    required this.email,
    required this.password,
  });

  final String name;
  final String email;
  final String password;
}

class _CreateOwnerDialog extends StatefulWidget {
  const _CreateOwnerDialog();

  @override
  State<_CreateOwnerDialog> createState() => _CreateOwnerDialogState();
}

class _CreateOwnerDialogState extends State<_CreateOwnerDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    // AF-14d: what the client can tell is wrong never reaches the API. What it
    // cannot — a password the API's own rules reject — comes back as an error.
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    Navigator.of(context).pop(
      _OwnerDraft(
        name: _name.text.trim(),
        email: _email.text.trim(),
        password: _password.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Create a co-owner'),
    content: Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          TextFormField(
            controller: _name,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Name'),
            validator: (value) =>
                (value?.trim().isEmpty ?? true) ? 'Enter a name.' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _email,
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
          const SizedBox(height: 12),
          TextFormField(
            controller: _password,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Password'),
            validator: (value) =>
                (value?.isEmpty ?? true) ? 'Enter a password.' : null,
          ),
        ],
      ),
    ),
    actions: <Widget>[
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _submit, child: const Text('Create')),
    ],
  );
}
