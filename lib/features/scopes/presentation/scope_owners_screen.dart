import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/result/result.dart';
import '../../../shared/forms/field_rules.dart';
import '../../../shared/forms/form_feedback.dart';
import '../../../shared/formatting/date_time_format.dart';
import '../../../shared/layout/app_shell.dart';
import '../../../shared/widgets/collection_pager.dart';
import '../../../shared/widgets/collection_states.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/failure_banner.dart';
import '../../../shared/widgets/notice.dart';
import '../../auth/domain/session.dart';
import '../../auth/presentation/session_controller.dart';
import '../../persons/domain/person.dart';
import '../../persons/presentation/scope_admin_picker.dart';
import '../../scope_invitations/domain/scope_invitation.dart';
import 'scope_owners_controller.dart';
import 'scope_users_controller.dart';

/// UI-14 — the owners of one scope, its pending invitations, and the five ways
/// they change.
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      ref.read(scopeOwnersControllerProvider(widget.scopeId).notifier).load();
      ref.read(scopeUsersControllerProvider(widget.scopeId).notifier).load();
    });
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

    if (chosen == null || !mounted) {
      return;
    }

    final result = await _controller.addOwner(chosen.id);

    // The picker can stay open while the owners reload or another command is
    // on its way; the add is then never sent, and silence would read as done.
    if (result is OwnerCommandNotSent && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          key: Key('owner-add-not-sent'),
          content: Text(
            'Nothing was sent: the owners are still loading or busy. '
            'Wait a moment and try again.',
          ),
        ),
      );
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
      destructive: true,
    );

    if (confirmed && mounted) {
      await _controller.removeOwner(owner.id);
    }
  }

  /// UC-58 — a withdrawal asks first, and a dismissed dialog sends nothing.
  Future<void> _withdraw(OwnerInvitation invitation) async {
    final confirmed = await showConfirm(
      context: context,
      title: 'Withdraw the invitation to ${invitation.inviteeName}?',
      message:
          '${invitation.inviteeName} will no longer be able to accept it. '
          'You can invite them again later.',
      confirmLabel: 'Withdraw',
    );

    if (confirmed && mounted) {
      await _controller.withdraw(invitation);
    }
  }

  /// The invitee's address, and when the invitation runs out.
  String _invitationLine(OwnerInvitation invitation) {
    final expiresAt = invitation.expiresAt;

    return expiresAt == null
        ? invitation.inviteeEmail
        : '${invitation.inviteeEmail} · Expires '
              '${formatDateTime(context, expiresAt)}';
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
        // AF-14h: an add that invited rather than added says so.
        if (state.notice case final notice?) ...<Widget>[
          Notice(notice),
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
        Column(
          key: const Key('owners-section'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
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
            // #159: a scope can have more owners than one page.
            if (state.ownersPage.totalPages > 1)
              CollectionPager(
                pageNumber: state.ownersPage.pageNumber,
                totalPages: state.ownersPage.totalPages,
                totalItems: state.ownersPage.totalItems,
                onPageChanged: state.busy ? null : _controller.goToOwnersPage,
              ),
          ],
        ),
        if (state.invitations.isNotEmpty) ...<Widget>[
          const SizedBox(height: 24),
          Text('Pending invitations', style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            'They become owners only once they accept, signed in as '
            'themselves.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: <Widget>[
                for (final invitation in state.invitations)
                  ListTile(
                    leading: const Icon(Icons.schedule_send_outlined),
                    title: Text(invitation.inviteeName),
                    subtitle: Text(_invitationLine(invitation)),
                    trailing: TextButton(
                      onPressed: state.busy
                          ? null
                          : () => _withdraw(invitation),
                      child: const Text('Withdraw'),
                    ),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
        Text('Promote a user', style: theme.textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          'A user of this scope can be promoted to Scope Admin, which makes '
          'them a co-owner.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
        _PromotionSection(
          scopeId: widget.scopeId,
          ownerIds: state.ownerIds,
          busy: state.busy,
          onPromote: _promote,
        ),
      ],
    );
  }
}

/// UI-14's promotion list: the scope's users, searched and paged by the API so
/// that every one of them can be reached, not only the first page (#159).
class _PromotionSection extends ConsumerStatefulWidget {
  const _PromotionSection({
    required this.scopeId,
    required this.ownerIds,
    required this.busy,
    required this.onPromote,
  });

  final String scopeId;

  /// Owners the screen already knows, who are never offered.
  final Set<String> ownerIds;

  /// A command is on its way, so promoting is disabled.
  final bool busy;
  final ValueChanged<Person> onPromote;

  @override
  ConsumerState<_PromotionSection> createState() => _PromotionSectionState();
}

class _PromotionSectionState extends ConsumerState<_PromotionSection> {
  final _search = TextEditingController();

  ScopeUsersController get _controller =>
      ref.read(scopeUsersControllerProvider(widget.scopeId).notifier);

  @override
  void initState() {
    super.initState();
    // The listing outlives the screen, so what the last visit searched for is
    // still in it; the box shows that rather than an empty field over a
    // narrowed list.
    _search.text = ref
        .read(scopeUsersControllerProvider(widget.scopeId))
        .query
        .search;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(scopeUsersControllerProvider(widget.scopeId));

    return Column(
      key: const Key('promotion-section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        TextField(
          key: const Key('promotion-search'),
          controller: _search,
          decoration: InputDecoration(
            labelText: 'Search users',
            helperText: 'By name, or by email address.',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: IconButton(
              tooltip: 'Search',
              icon: const Icon(Icons.arrow_forward),
              onPressed: () => _controller.search(_search.text),
            ),
          ),
          onSubmitted: _controller.search,
        ),
        const SizedBox(height: 8),
        switch (state) {
          ScopeUsersLoading() => const Padding(
            padding: EdgeInsets.all(16),
            child: LinearProgressIndicator(),
          ),
          ScopeUsersFailed(:final failure) => CollectionFailed(
            failure: failure,
            onRetry: _controller.load,
          ),
          final ScopeUsersLoaded loaded => _users(loaded),
        },
      ],
    );
  }

  Widget _users(ScopeUsersLoaded state) {
    final offered = state.page.items
        .where((user) => !widget.ownerIds.contains(user.id))
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (state.busy) const LinearProgressIndicator(),
        if (offered.isEmpty)
          state.query.isFiltered
              ? const CollectionEmpty(
                  title: 'Nobody matches',
                  message: 'No user of this scope matches that search.',
                  icon: Icons.search_off,
                )
              : const CollectionEmpty(
                  title: 'Nobody to promote',
                  message:
                      'This scope has no users who are not already owners.',
                  icon: Icons.people_outline,
                )
        else
          Card(
            child: Column(
              children: <Widget>[
                for (final user in offered)
                  ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: Text(user.name),
                    subtitle: Text(user.email),
                    trailing: TextButton(
                      onPressed: widget.busy
                          ? null
                          : () => widget.onPromote(user),
                      child: const Text('Promote'),
                    ),
                  ),
              ],
            ),
          ),
        if (state.page.totalPages > 1)
          CollectionPager(
            pageNumber: state.page.pageNumber,
            totalPages: state.page.totalPages,
            totalItems: state.page.totalItems,
            onPageChanged: state.busy ? null : _controller.goToPage,
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

  /// Sends the draft, answering with what became of it.
  final Future<OwnerCommandResult> Function(_OwnerDraft draft) onSubmit;

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
  bool _notSent = false;

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
      _notSent = false;
    });

    final result = await widget.onSubmit(
      _OwnerDraft(
        name: _name.text.trim(),
        email: _email.text.trim(),
        password: _password.text,
      ),
    );

    if (!mounted) {
      return;
    }

    switch (result) {
      case OwnerCommandDone():
        Navigator.of(context).pop();
      case OwnerCommandRefused(:final failure):
        setState(() {
          _sending = false;
          _refusal = failure;
        });
      case OwnerCommandNotSent():
        // The owners were loading or busy: keep what was typed and say so,
        // rather than closing as if the owner had been created.
        setState(() {
          _sending = false;
          _notSent = true;
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
          if (_notSent) ...<Widget>[
            const Text(
              'Nothing was sent: the owners are still loading or busy. '
              'Wait a moment and try again.',
              key: Key('owner-not-sent'),
            ),
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
            autofillHints: const <String>[AutofillHints.newPassword],
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
