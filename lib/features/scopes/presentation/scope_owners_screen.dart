import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/result/result.dart';
import '../../../shared/forms/field_rules.dart';
import '../../../shared/forms/form_feedback.dart';
import '../../../shared/layout/app_shell.dart';
import '../../../shared/widgets/collection_states.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/failure_banner.dart';
import '../../auth/domain/session.dart';
import '../../auth/presentation/session_controller.dart';
import '../../persons/domain/person.dart';
import '../../persons/presentation/scope_admin_picker.dart';
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

  /// AF-14c — the API leaves this scope's current owners out of the listing,
  /// so somebody who already owns it is never offered in the first place.
  Future<void> _addExisting() async {
    final chosen = await showScopeAdminPicker(
      context: context,
      excludeOwnersOfScopeId: widget.scopeId,
    );

    if (chosen != null && mounted) {
      await _controller.addOwner(chosen.id);
    }
  }

  /// AF-14d — the dialog stays open until the API accepts the draft, so a
  /// refusal is read beside what was typed rather than costing the retyping.
  Future<void> _createNew() => showDialog<void>(
    context: context,
    builder: (context) => _CreateOwnerDialog(
      onSubmit: (draft) => _controller.createOwner(
        name: draft.name,
        email: draft.email,
        password: draft.password,
      ),
    ),
  );

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
      backRoute: '/scopes/${widget.scopeId}',
      backTooltip: 'Back to the scope',
      body: switch (state) {
        ScopeOwnersLoading() => const CollectionLoading(rows: 4),
        // A Scope Admin who has just removed their own ownership is refused
        // the scope from then on; retrying would only be refused again.
        ScopeOwnersUnavailable(:final failure)
            when failure.kind == FailureKind.forbidden =>
          CollectionEmpty(
            title: 'Not available for your role',
            message:
                'This scope is not one you administer. Nothing is wrong '
                'with your session.',
            icon: Icons.lock_person_outlined,
            actionLabel: 'Back to scopes',
            onAction: () => context.go('/scopes'),
          ),
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
  const _CreateOwnerDialog({required this.onSubmit});

  /// Sends the draft, answering with the API's refusal or `null` once the
  /// owner exists.
  final Future<Failure?> Function(_OwnerDraft draft) onSubmit;

  @override
  State<_CreateOwnerDialog> createState() => _CreateOwnerDialogState();
}

class _CreateOwnerDialogState extends State<_CreateOwnerDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _sending = false;
  Failure? _refusal;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // AF-14d: what the client can tell is wrong never reaches the API. What it
    // cannot — a password the API's own rules reject — comes back as an error.
    if (_sending || !validateAndReveal(_formKey)) {
      return;
    }

    setState(() {
      _sending = true;
      _refusal = null;
    });

    final refusal = await widget.onSubmit(
      _OwnerDraft(
        name: _name.text.trim(),
        email: _email.text.trim(),
        password: _password.text,
      ),
    );

    if (!mounted) {
      return;
    }

    if (refusal == null) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _sending = false;
        _refusal = refusal;
      });
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    // Scrolls rather than overflowing when a phone's keyboard is open.
    scrollable: true,
    title: const Text('Create a co-owner'),
    content: Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // The API's own words, with everything typed still in place.
          if (_refusal case final refusal?) ...<Widget>[
            ErrorBanner(failure: refusal),
            const SizedBox(height: 12),
          ],
          TextFormField(
            maxLength: nameMaxLength,
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

              return isPlausibleEmail(email)
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
                validateNewPassword(value, emptyMessage: 'Enter a password.'),
          ),
        ],
      ),
    ),
    actions: <Widget>[
      TextButton(
        onPressed: _sending ? null : () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(
        style: FilledButton.styleFrom(minimumSize: const Size(96, 40)),
        onPressed: _sending ? null : _submit,
        child: _sending
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Create'),
      ),
    ],
  );
}
