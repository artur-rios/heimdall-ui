import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/result/result.dart';
import '../../../shared/forms/field_rules.dart';
import '../../../shared/forms/form_feedback.dart';
import '../../../shared/layout/app_shell.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/failure_banner.dart';
import '../../auth/domain/session.dart';
import '../../auth/presentation/session_controller.dart';
import '../../persons/domain/person.dart';
import '../../persons/presentation/scope_members.dart';
import 'application_create_controller.dart';

/// UI-21 — the create-application form.
class ApplicationCreateScreen extends ConsumerStatefulWidget {
  const ApplicationCreateScreen({required this.scopeId, super.key});

  final String scopeId;

  @override
  ConsumerState<ApplicationCreateScreen> createState() =>
      _ApplicationCreateScreenState();
}

class _ApplicationCreateScreenState
    extends ConsumerState<ApplicationCreateScreen> {
  @override
  void initState() {
    super.initState();
    // A refused or finished attempt from an earlier visit is not this one's:
    // the form starts clean every time it is opened.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) =>
          ref.invalidate(applicationCreateControllerProvider(widget.scopeId)),
    );
  }

  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  String? _ownerId;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  /// Whether anything has been entered, which is what AF-21d asks about.
  bool get _isDirty => _name.text.trim().isNotEmpty || _ownerId != null;

  Future<void> _submit() async {
    // AF-21a: an empty name, or no owner, never reaches the API — and the form
    // says which.
    if (!validateAndReveal(_formKey)) {
      return;
    }

    final ownerId = _ownerId;

    // The owner field's own validator has already refused this; the check
    // only narrows the type.
    if (ownerId == null) {
      return;
    }

    await ref
        .read(applicationCreateControllerProvider(widget.scopeId).notifier)
        .create(name: _name.text.trim(), ownerId: ownerId);
  }

  /// The owner requirement, so choosing one can clear its refusal at once
  /// rather than at the next submission.
  final _ownerField = GlobalKey<FormFieldState<String>>();

  void _chooseOwner(String? id) {
    setState(() => _ownerId = id);

    if (_ownerField.currentState?.hasError ?? false) {
      _ownerField.currentState!.validate();
    }
  }

  /// AF-21d — leaving a modified form asks first, whichever way it is left:
  /// Cancel, the back control, the navigation, or signing out.
  Future<bool> _confirmLeave() async =>
      !_isDirty ||
      await showConfirm(
        context: context,
        title: 'Discard this application?',
        message: 'What you have entered has not been saved and will be lost.',
        confirmLabel: 'Discard',
        destructive: true,
        cancelLabel: 'Keep editing',
      );

  Future<void> _cancel() async {
    if (await _confirmLeave() && mounted) {
      context.go('/scopes/${widget.scopeId}/applications');
    }
  }

  /// The owner selector, or what stands in for it while there is nothing to
  /// select from.
  Widget _ownerChoice(
    ThemeData theme,
    AsyncValue<List<Person>> members,
    bool sending,
  ) {
    return switch (members) {
      AsyncData<List<Person>>(:final value) when value.isEmpty => Text(
        'Nobody can own an application in this scope yet: an '
        'owner must be one of the scope’s owners.',
        style: theme.textTheme.bodyMedium,
      ),
      AsyncData<List<Person>>(:final value) => DropdownButtonFormField<String>(
        initialValue: _ownerId,
        // A person's name and address together are wider than
        // a narrow window, so the field takes the width it has
        // and the label gives way rather than overflowing.
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
        onChanged: sending ? null : _chooseOwner,
      ),
      AsyncError<List<Person>>() => Row(
        children: <Widget>[
          Expanded(
            child: Text(
              'The people of this scope could not be read, so there '
              'is nobody to choose from.',
              style: theme.textTheme.bodyMedium,
            ),
          ),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(
      applicationCreateControllerProvider(widget.scopeId),
    );
    final session = ref.watch(sessionControllerProvider);
    // AF-16c at the API: a Scope Admin may only create applications they own
    // themselves (`CannotSetAnotherOwner`), so they are the only choice offered.
    final ownOnly = switch (session) {
      Authenticated(:final principal) when principal.isScopeAdmin =>
        principal.id,
      _ => null,
    };
    final members = ref
        .watch(scopeMembersProvider(widget.scopeId))
        .whenData(
          (people) => ownOnly == null
              ? people
              : people.where((person) => person.id == ownOnly).toList(),
        );
    final sending = state is ApplicationCreateSending;

    ref.listen<ApplicationCreateState>(
      applicationCreateControllerProvider(widget.scopeId),
      (previous, next) {
        if (next case ApplicationCreated(:final application)) {
          // The listing behind this form reads itself again once it is back
          // on top (`AppShell.onReturn`).
          context.go(
            '/scopes/${widget.scopeId}/applications/${application.id}',
          );
        }
      },
    );

    return AppShell(
      currentRoute: '/scopes',
      title: const Text('New application'),
      onBack: _cancel,
      confirmLeave: _confirmLeave,
      backTooltip: 'Back to the listing',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Form(
              key: _formKey,
              onChanged: () => setState(() {}),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    'Create an application',
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'An application uses this scope for its identity, and is '
                    'owned by one of the scope’s owners.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  if (state is ApplicationCreateRejected) ...<Widget>[
                    if (state.failure.kind == FailureKind.network)
                      RetryBanner(onRetry: sending ? null : _submit)
                    else
                      // AF-21b and AF-21c: the API's own strings, as returned.
                      ErrorBanner(failure: state.failure),
                    const SizedBox(height: 16),
                  ],
                  TextFormField(
                    maxLength: nameMaxLength,
                    controller: _name,
                    decoration: const InputDecoration(labelText: 'Name'),
                    validator: (value) => (value?.trim().isEmpty ?? true)
                        ? 'Enter a name for the application.'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  // AF-21c: only the scope's owners are offered, so the
                  // refusal the API would give is not invited in the first
                  // place. The field refuses a submission with no owner chosen
                  // and says why, including when there is nobody to choose.
                  FormField<String>(
                    key: _ownerField,
                    validator: (_) => _ownerId != null
                        ? null
                        : switch (members) {
                            AsyncData<List<Person>>(:final value)
                                when value.isNotEmpty =>
                              'Choose an owner for the application.',
                            _ =>
                              'An application needs an owner, and nobody here '
                                  'can own one yet.',
                          },
                    builder: (field) => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        _ownerChoice(theme, members, sending),
                        if (field.errorText case final error?) ...<Widget>[
                          const SizedBox(height: 8),
                          FormRequirementError(error),
                        ] else if (_ownerId == null) ...<Widget>[
                          const SizedBox(height: 8),
                          Text(
                            'No owner selected yet.',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: sending ? null : _submit,
                    child: sending
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Create application'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: sending ? null : _cancel,
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
