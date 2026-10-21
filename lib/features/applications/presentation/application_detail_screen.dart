import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/result/result.dart';
import '../../../shared/forms/edit_mode.dart';
import '../../../shared/forms/field_rules.dart';
import '../../../shared/forms/form_feedback.dart';
import '../../../shared/layout/app_shell.dart';
import '../../../shared/widgets/collection_states.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/failure_banner.dart';
import '../../../shared/widgets/notice.dart';
import '../../auth/domain/session.dart';
import '../../auth/presentation/session_controller.dart';
import '../../persons/domain/person.dart';
import '../../persons/presentation/scope_members.dart';
import '../domain/application.dart';
import 'application_detail_controller.dart';
import 'application_list_controller.dart';
import 'credentials_card.dart';

/// UI-22 — one application: what it is called and who owns it.
class ApplicationDetailScreen extends ConsumerStatefulWidget {
  const ApplicationDetailScreen({
    required this.scopeId,
    required this.applicationId,
    super.key,
  });

  final String scopeId;
  final String applicationId;

  @override
  ConsumerState<ApplicationDetailScreen> createState() =>
      _ApplicationDetailScreenState();
}

class _ApplicationDetailScreenState
    extends ConsumerState<ApplicationDetailScreen> {
  var _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  String? _ownerId;

  /// The record the fields were last seeded from, which is what AF-22e
  /// compares against.
  Application? _seeded;

  /// Whether the person has asked to change the record. The fields are
  /// read-only until they do, and again once the change is saved or dropped.
  bool _editing = false;

  ApplicationRef get _ref => ApplicationRef(
    scopeId: widget.scopeId,
    applicationId: widget.applicationId,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) =>
          ref.read(applicationDetailControllerProvider(_ref).notifier).load(),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  /// Copies a freshly read or freshly saved record into the fields.
  ///
  /// AF-22c is why this only runs when the record itself changed: a refused
  /// save must leave what the user chose exactly where it was.
  void _seed(Application application) {
    if (identical(_seeded, application)) {
      return;
    }

    _seeded = application;
    _restore(application);
  }

  void _restore(Application application) {
    _name.text = application.name;
    _ownerId = application.ownerId.isEmpty ? null : application.ownerId;
  }

  void _startEditing() {
    ref
        .read(applicationDetailControllerProvider(_ref).notifier)
        .acknowledgeSave();
    setState(() => _editing = true);
  }

  /// Leaving with unsaved changes — by the navigation, the back control or
  /// signing out — asks first.
  Future<bool> _confirmLeave() =>
      confirmDiscardChanges(context, hasChanges: _hasUnsavedEdit);

  bool get _hasUnsavedEdit {
    final seeded = _seeded;

    return _editing && seeded != null && _differsFrom(seeded);
  }

  /// Puts back what the API holds and leaves edit mode, dropping any refusal
  /// along with the edit it was about.
  void _cancelEditing() {
    ref
        .read(applicationDetailControllerProvider(_ref).notifier)
        .acknowledgeSave();
    setState(() {
      _editing = false;
      // A fresh key forgets the fields' validation messages too.
      _formKey = GlobalKey<FormState>();

      if (_seeded case final application?) {
        _restore(application);
      }
    });
  }

  bool _differsFrom(Application application) =>
      _name.text.trim() != application.name ||
      (_ownerId ?? '') != application.ownerId;

  /// AF-23d — only a System Admin erases an application permanently.
  bool get _maySeeHardDelete {
    final session = ref.watch(sessionControllerProvider);

    return session is Authenticated && session.principal.isSystemAdmin;
  }

  /// AF-23a — a dialog the user closes sends nothing.
  Future<void> _confirmDelete(Application application) async {
    final confirmed = await showConfirm(
      context: context,
      title: 'Delete ${application.name}?',
      message:
          '${application.name} will be marked deleted. The record is '
          'kept and the API can restore it.',
      confirmLabel: 'Delete',
    );

    if (confirmed && mounted) {
      await ref
          .read(applicationDetailControllerProvider(_ref).notifier)
          .delete();
    }
  }

  /// AF-23c — the confirm control stays disabled until the name matches.
  Future<void> _confirmDeletePermanently(Application application) async {
    final confirmed = await showTypeToConfirm(
      context: context,
      title: 'Delete ${application.name} permanently?',
      message:
          'The application and everything recorded against it are '
          'erased. This cannot be undone. Type its name to confirm:',
      confirmationValue: application.name,
      fieldLabel: 'Application name',
      confirmLabel: 'Delete permanently',
    );

    if (confirmed && mounted) {
      await ref
          .read(applicationDetailControllerProvider(_ref).notifier)
          .deletePermanently();
    }
  }

  Future<void> _save() async {
    if (!validateAndReveal(_formKey)) {
      return;
    }

    final ownerId = _ownerId;

    // The owner field's own validator has already refused this, on screen; the
    // check only narrows the type.
    if (ownerId == null) {
      return;
    }

    await ref
        .read(applicationDetailControllerProvider(_ref).notifier)
        .save(name: _name.text.trim(), ownerId: ownerId);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(applicationDetailControllerProvider(_ref));
    final controller = ref.read(
      applicationDetailControllerProvider(_ref).notifier,
    );
    final backToListing = '/scopes/${widget.scopeId}/applications';

    // A deleted application returns to the listing, which is now stale.
    ref.listen<ApplicationDetailState>(
      applicationDetailControllerProvider(_ref),
      (previous, next) {
        // A save that went through ends the edit.
        if (previous is ApplicationDetailLoaded &&
            previous.saving &&
            next is ApplicationDetailLoaded &&
            next.saved) {
          setState(() => _editing = false);
        }

        if (next is ApplicationDeleted) {
          ref
              .read(applicationListControllerProvider(widget.scopeId).notifier)
              .load();
          context.go(backToListing);
        }
      },
    );

    return AppShell(
      currentRoute: '/scopes',
      title: Text(switch (state) {
        ApplicationDetailLoaded(:final application) => application.name,
        _ => 'Application',
      }),
      confirmLeave: _confirmLeave,
      backRoute: backToListing,
      backTooltip: 'Back to the listing',
      body: switch (state) {
        ApplicationDetailLoading() => const Center(
          child: CircularProgressIndicator(),
        ),
        // AF-22a — no such application.
        ApplicationDetailUnavailable(isNotFound: true) => CollectionEmpty(
          title: 'Application not found',
          message:
              'There is no application with that identifier. It may have '
              'been permanently deleted.',
          icon: Icons.search_off_outlined,
          actionLabel: 'Back to the listing',
          onAction: () => context.go(backToListing),
        ),
        // AF-22b — out of this role's reach.
        ApplicationDetailUnavailable(isForbidden: true) => CollectionEmpty(
          title: 'Not available for your role',
          message:
              'This application is not one you administer. Nothing is '
              'wrong with your session.',
          icon: Icons.lock_person_outlined,
          actionLabel: 'Back to the listing',
          onAction: () => context.go(backToListing),
        ),
        ApplicationDetailUnavailable(:final failure) => CollectionFailed(
          failure: failure,
          onRetry: controller.load,
        ),
        // The listing is where a deleted application leaves the user; this is
        // the frame in between.
        ApplicationDeleted() => const Center(
          child: CircularProgressIndicator(),
        ),
        final ApplicationDetailLoaded loaded => _detail(loaded),
      },
    );
  }

  Widget _detail(ApplicationDetailLoaded state) {
    final theme = Theme.of(context);
    _seed(state.application);
    final application = state.application;
    final editing = _editing && !state.isReadOnly;
    final members = ref.watch(scopeMembersProvider(widget.scopeId));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // AF-22d — a deleted application says so before anything else.
              if (state.isReadOnly) ...<Widget>[
                const Notice(
                  'This application is deleted. It is shown for '
                  'reference and cannot be changed from here.',
                  icon: Icons.delete_outline,
                  isError: true,
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
                        // AF-22c: the API's own strings, as returned.
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
                      mayEdit: !state.isReadOnly,
                      saving: state.saving,
                      // AF-22e: nothing to save is not an action.
                      canSave: _differsFrom(application) && !state.deleting,
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
                                ? 'Enter a name for the application.'
                                : null,
                          ),
                          const SizedBox(height: 16),
                          _owner(state, members, editing: editing),
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
                        _Fact(label: 'Identifier', value: application.id),
                        _Fact(
                          label: 'Scope',
                          value: application.scopeId ?? widget.scopeId,
                        ),
                        _Fact(
                          label: 'State',
                          value: application.isDeleted ? 'Deleted' : 'Active',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // UI-37 — a deleted application's credentials are inert, and the
              // API answers 404 for it, so the card is not offered.
              if (!state.isReadOnly) ...<Widget>[
                const SizedBox(height: 24),
                CredentialsCard(
                  scopeId: widget.scopeId,
                  applicationId: widget.applicationId,
                ),
                // AF-22d leaves a deleted application nothing left to delete.
                const SizedBox(height: 24),
                _DangerZone(
                  application: application,
                  deleting: state.deleting || state.saving,
                  failure: state.deleteFailure,
                  mayDeletePermanently: _maySeeHardDelete,
                  onDelete: _confirmDelete,
                  onDeletePermanently: _confirmDeletePermanently,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// The owner, as a selector over the scope's own people.
  ///
  /// A deleted application shows the owner it has rather than a control, since
  /// there is nothing to change; an owner the listing does not contain is shown
  /// by identifier for the same reason UI-20's rows are (FR-AP-08).
  Widget _owner(
    ApplicationDetailLoaded state,
    AsyncValue<List<Person>> members, {
    required bool editing,
  }) {
    final theme = Theme.of(context);
    final application = state.application;

    if (!editing) {
      return InputDecorator(
        decoration: recordFieldDecoration(
          context,
          label: 'Owner',
          editing: false,
        ),
        child: Text(_ownerLabel(members, application)),
      );
    }

    return switch (members) {
      AsyncData<List<Person>>(:final value)
          when value.isEmpty && _ownerId == null =>
        Text(
          'This scope has nobody who could own an application.',
          style: theme.textTheme.bodyMedium,
        ),
      AsyncData<List<Person>>(:final value) => DropdownButtonFormField<String>(
        initialValue: _ownerId,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Owner'),
        validator: (_) =>
            _ownerId == null ? 'Choose an owner for the application.' : null,
        items: <DropdownMenuItem<String>>[
          // The owner the application has is always on show. One the listing
          // does not hold — past its first page, or no longer in the scope —
          // would otherwise leave the field blank while Save still sends the
          // old id. It cannot be picked again, only kept.
          if (_ownerId case final current?
              when !value.any((person) => person.id == current))
            DropdownMenuItem<String>(
              value: current,
              enabled: false,
              child: Text(
                _ownerLabel(members, application),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          for (final person in value)
            DropdownMenuItem<String>(
              value: person.id,
              child: Text(
                '${person.name} (${person.email})',
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: state.saving ? null : (id) => setState(() => _ownerId = id),
      ),
      AsyncError<List<Person>>() => Row(
        children: <Widget>[
          Expanded(
            child: _Fact(
              label: 'Owner',
              value: _ownerLabel(members, application),
            ),
          ),
          // A failed read stays cached for the session, so the way out is to
          // ask again.
          TextButton(
            onPressed: () =>
                ref.invalidate(scopeMembersProvider(widget.scopeId)),
            child: const Text('Retry'),
          ),
        ],
      ),
      _ => const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: LinearProgressIndicator(),
      ),
    };
  }

  String _ownerLabel(
    AsyncValue<List<Person>> members,
    Application application,
  ) {
    for (final person in members.value ?? const <Person>[]) {
      if (person.id == application.ownerId) {
        return person.name;
      }
    }

    return application.ownerId.isEmpty ? 'Nobody' : application.ownerId;
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

/// The two deletions, kept apart from the rest of the screen because neither
/// is an ordinary edit.
class _DangerZone extends StatelessWidget {
  const _DangerZone({
    required this.application,
    required this.deleting,
    required this.failure,
    required this.mayDeletePermanently,
    required this.onDelete,
    required this.onDeletePermanently,
  });

  final Application application;
  final bool deleting;
  final Failure? failure;

  /// AF-23d — a Scope Admin never sees the permanent deletion.
  final bool mayDeletePermanently;

  final Future<void> Function(Application application) onDelete;
  final Future<void> Function(Application application) onDeletePermanently;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Delete this application',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Deleting keeps the record and can be undone by the API. '
              'Deleting permanently erases it.',
              style: TextStyle(color: theme.colorScheme.onErrorContainer),
            ),
            // AF-23b — the API refused, and the application is still open.
            if (failure case final refusal?) ...<Widget>[
              const SizedBox(height: 16),
              ErrorBanner(failure: refusal),
            ],
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                OutlinedButton.icon(
                  onPressed: deleting ? null : () => onDelete(application),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete application'),
                ),
                if (mayDeletePermanently)
                  FilledButton.icon(
                    onPressed: deleting
                        ? null
                        : () => onDeletePermanently(application),
                    icon: const Icon(Icons.delete_forever_outlined),
                    label: const Text('Delete permanently'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
