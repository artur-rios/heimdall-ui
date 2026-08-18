import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/result/result.dart';
import '../../../shared/widgets/collection_states.dart';
import '../../../shared/widgets/failure_banner.dart';
import '../domain/person.dart';
import 'scope_admin_picker_controller.dart';

/// Asks for a Scope Admin, and answers with the one chosen.
///
/// [excludeOwnersOfScopeId] leaves out the people who already own that scope,
/// which is UI-14's AF-14c. [excludeIds] leaves out the ones the calling screen
/// has already collected but not yet sent — UI-11's chips, which the API cannot
/// know about because the scope does not exist yet.
Future<PersonSummary?> showScopeAdminPicker({
  required BuildContext context,
  String? excludeOwnersOfScopeId,
  Set<String> excludeIds = const <String>{},
}) => showDialog<PersonSummary>(
  context: context,
  builder: (context) => ScopeAdminPicker(
    excludeOwnersOfScopeId: excludeOwnersOfScopeId,
    excludeIds: excludeIds,
  ),
);

/// The picker itself, public so a widget test can pump it on its own.
class ScopeAdminPicker extends ConsumerStatefulWidget {
  const ScopeAdminPicker({
    super.key,
    this.excludeOwnersOfScopeId,
    this.excludeIds = const <String>{},
  });

  final String? excludeOwnersOfScopeId;
  final Set<String> excludeIds;

  @override
  ConsumerState<ScopeAdminPicker> createState() => _ScopeAdminPickerState();
}

class _ScopeAdminPickerState extends ConsumerState<ScopeAdminPicker> {
  final _search = TextEditingController();
  final _identifier = TextEditingController();

  String get _key => widget.excludeOwnersOfScopeId ?? '';

  ScopeAdminPickerController get _controller =>
      ref.read(scopeAdminPickerControllerProvider(_key).notifier);

  @override
  void initState() {
    super.initState();
    // The exclusion changes as owners are added, so the listing is read afresh
    // each time the picker opens rather than trusted from the last one.
    WidgetsBinding.instance.addPostFrameCallback((_) => _controller.search());
  }

  @override
  void dispose() {
    _search.dispose();
    _identifier.dispose();
    super.dispose();
  }

  void _choose(PersonSummary admin) => Navigator.of(context).pop(admin);

  /// The escape hatch: an identifier stands in for a person the listing could
  /// not offer. The API judges it exactly as it judged the typed identifiers
  /// this picker replaced (AF-11c, AF-14b).
  void _chooseTyped() {
    final id = _identifier.text.trim();

    if (id.isNotEmpty) {
      Navigator.of(context).pop(PersonSummary(id: id, name: id, email: ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(scopeAdminPickerControllerProvider(_key));

    return AlertDialog(
      title: const Text('Choose a Scope Admin'),
      content: SizedBox(
        width: 420,
        height: 360,
        child: switch (state) {
          ScopeAdminsLoading() => const CollectionLoading(rows: 4),
          ScopeAdminsUnavailable(:final failure) => _Unavailable(
            failure: failure,
            identifier: _identifier,
            onRetry: () => _controller.search(_search.text),
            onSubmit: _chooseTyped,
          ),
          final ScopeAdminsLoaded loaded => _Candidates(
            state: loaded,
            search: _search,
            excludeIds: widget.excludeIds,
            onSearch: _controller.search,
            onChoose: _choose,
          ),
        },
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

class _Candidates extends StatelessWidget {
  const _Candidates({
    required this.state,
    required this.search,
    required this.excludeIds,
    required this.onSearch,
    required this.onChoose,
  });

  final ScopeAdminsLoaded state;
  final TextEditingController search;
  final Set<String> excludeIds;
  final ValueChanged<String> onSearch;
  final ValueChanged<PersonSummary> onChoose;

  @override
  Widget build(BuildContext context) {
    final offered = state.candidates
        .where((admin) => !excludeIds.contains(admin.id))
        .toList(growable: false);

    return Column(
      children: <Widget>[
        TextField(
          controller: search,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Search',
            helperText: 'By name, or by email address.',
            prefixIcon: Icon(Icons.search),
          ),
          onSubmitted: onSearch,
        ),
        const SizedBox(height: 8),
        if (state.searching) const LinearProgressIndicator(),
        Expanded(
          child: offered.isEmpty
              ? const CollectionEmpty(
                  title: 'No Scope Admins to offer',
                  message:
                      'Nobody matches, or everybody who does already owns '
                      'this scope.',
                  icon: Icons.shield_outlined,
                )
              : ListView(
                  children: <Widget>[
                    for (final admin in offered)
                      ListTile(
                        leading: const Icon(Icons.shield_outlined),
                        title: Text(admin.name),
                        subtitle: Text(admin.email),
                        onTap: () => onChoose(admin),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _Unavailable extends StatelessWidget {
  const _Unavailable({
    required this.failure,
    required this.identifier,
    required this.onRetry,
    required this.onSubmit,
  });

  final Failure failure;
  final TextEditingController identifier;
  final VoidCallback onRetry;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) => ListView(
    children: <Widget>[
      // The banners rather than `CollectionFailed`: this is a panel inside a
      // dialog, and a centred full-height failure would push the identifier
      // out of reach.
      if (failure.kind == FailureKind.network)
        RetryBanner(onRetry: onRetry)
      else ...<Widget>[
        ErrorBanner(failure: failure),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ),
      ],
      const SizedBox(height: 16),
      Text(
        'You can still name someone by their identifier.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      const SizedBox(height: 8),
      TextField(
        controller: identifier,
        decoration: const InputDecoration(
          labelText: 'Person identifier',
          helperText: 'The person id of an existing Scope Admin.',
        ),
        onSubmitted: (_) => onSubmit(),
      ),
      const SizedBox(height: 8),
      Align(
        alignment: Alignment.centerRight,
        child: FilledButton(
          onPressed: onSubmit,
          child: const Text('Use this identifier'),
        ),
      ),
    ],
  );
}
