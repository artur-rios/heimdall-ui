import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/result/result.dart';
import '../../../shared/layout/app_shell.dart';
import '../../../shared/widgets/collection_states.dart';
import '../../../shared/widgets/failure_banner.dart';
import '../../persons/domain/person.dart';
import '../../persons/presentation/scope_members.dart';
import '../domain/application.dart';
import 'application_detail_controller.dart';

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
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  String? _ownerId;

  /// The record the fields were last seeded from, which is what AF-22e
  /// compares against.
  Application? _seeded;

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
    _name.text = application.name;
    _ownerId = application.ownerId.isEmpty ? null : application.ownerId;
  }

  bool _differsFrom(Application application) =>
      _name.text.trim() != application.name ||
      (_ownerId ?? '') != application.ownerId;

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final ownerId = _ownerId;

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

    return AppShell(
      currentRoute: '/scopes',
      title: Text(switch (state) {
        ApplicationDetailLoaded(:final application) => application.name,
        _ => 'Application',
      }),
      actions: <Widget>[
        IconButton(
          tooltip: 'Back to the listing',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(backToListing),
        ),
      ],
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
        final ApplicationDetailLoaded loaded => _detail(loaded),
      },
    );
  }

  Widget _detail(ApplicationDetailLoaded state) {
    final theme = Theme.of(context);
    _seed(state.application);
    final application = state.application;
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
                const _Notice(
                  icon: Icons.delete_outline,
                  message:
                      'This application is deleted. It is shown for '
                      'reference and cannot be changed from here.',
                  destructive: true,
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
                          ? 'Enter a name for the application.'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    _owner(state, members),
                    const SizedBox(height: 16),
                    if (!state.isReadOnly)
                      FilledButton(
                        // AF-22e: nothing to save is not an action.
                        onPressed: (state.saving || !_differsFrom(application))
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
    AsyncValue<List<Person>> members,
  ) {
    final theme = Theme.of(context);
    final application = state.application;

    if (state.isReadOnly) {
      return _Fact(label: 'Owner', value: _ownerLabel(members, application));
    }

    return switch (members) {
      AsyncData<List<Person>>(:final value) when value.isEmpty => Text(
        'This scope has nobody who could own an application.',
        style: theme.textTheme.bodyMedium,
      ),
      AsyncData<List<Person>>(:final value) => DropdownButtonFormField<String>(
        initialValue: value.any((person) => person.id == _ownerId)
            ? _ownerId
            : null,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Owner'),
        items: <DropdownMenuItem<String>>[
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
      AsyncError<List<Person>>() => _Fact(
        label: 'Owner',
        value: _ownerLabel(members, application),
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
    for (final person in members.valueOrNull ?? const <Person>[]) {
      if (person.id == application.ownerId) {
        return person.name;
      }
    }

    return application.ownerId.isEmpty ? 'Nobody' : application.ownerId;
  }
}

/// A one-line panel: what a deleted record and a saved edit each say.
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
