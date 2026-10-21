import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/result/result.dart';
import '../../../shared/formatting/date_time_format.dart';
import '../../../shared/layout/app_shell.dart';
import '../../../shared/widgets/adaptive_collection.dart';
import '../../../shared/widgets/collection_states.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/failure_banner.dart';
import '../../../shared/widgets/notice.dart';
import '../domain/pending_registration.dart';
import 'pending_registration_list_controller.dart';
import 'scope_detail_controller.dart';

/// UI-35 — the people who signed up to a scope and have not confirmed yet.
class PendingRegistrationListScreen extends ConsumerStatefulWidget {
  const PendingRegistrationListScreen({required this.scopeId, super.key});

  final String scopeId;

  @override
  ConsumerState<PendingRegistrationListScreen> createState() =>
      _PendingRegistrationListScreenState();
}

class _PendingRegistrationListScreenState
    extends ConsumerState<PendingRegistrationListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_controller.load());

      // A deep link or a refresh arrives without the scope page having read
      // the scope, so it is read once here for the subtitle's name. Only
      // here, so a scope that cannot be read is not asked for again.
      final scope = ref.read(scopeDetailControllerProvider(widget.scopeId));
      if (scope is! ScopeDetailLoaded) {
        unawaited(
          ref
              .read(scopeDetailControllerProvider(widget.scopeId).notifier)
              .load(),
        );
      }
    });
  }

  PendingRegistrationListController get _controller => ref.read(
    pendingRegistrationListControllerProvider(widget.scopeId).notifier,
  );

  /// AF-35e — a dialog the user closes sends nothing.
  Future<void> _confirmDiscard(PendingRegistration registration) async {
    final confirmed = await showConfirm(
      context: context,
      title: 'Discard the registration for ${registration.email}?',
      message: 'Its confirmation link will stop working.',
      confirmLabel: 'Discard',
      destructive: true,
    );

    if (!confirmed || !mounted) {
      return;
    }

    await _controller.discard(registration);
  }

  /// The scope's name once it is read; the identifier until then, or when it
  /// cannot be read.
  String _scopeLabel() {
    final scope = ref.watch(scopeDetailControllerProvider(widget.scopeId));

    return scope is ScopeDetailLoaded ? scope.scope.name : widget.scopeId;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(
      pendingRegistrationListControllerProvider(widget.scopeId),
    );

    return AppShell(
      currentRoute: '/scopes',
      title: const Text('Pending registrations'),
      backRoute: '/scopes/${widget.scopeId}',
      backTooltip: 'Back to the scope',
      body: switch (state) {
        PendingRegistrationListLoading() => const CollectionLoading(),
        // AF-35b — the scope is not one this admin owns; retrying would only
        // be refused again.
        PendingRegistrationListFailed(:final failure)
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
        // AF-35c — the scope itself is gone.
        PendingRegistrationListFailed(:final failure)
            when failure.kind == FailureKind.notFound =>
          CollectionEmpty(
            title: 'Scope not found.',
            message: 'It may have been deleted.',
            actionLabel: 'Back to scopes',
            onAction: () => context.go('/scopes'),
          ),
        // AF-35f — the returned errors, with a retry.
        PendingRegistrationListFailed(:final failure) => CollectionFailed(
          failure: failure,
          onRetry: _controller.load,
        ),
        final PendingRegistrationListLoaded loaded => _loaded(loaded),
      },
    );
  }

  Widget _loaded(PendingRegistrationListLoaded loaded) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        child: Text(
          _scopeLabel(),
          style: Theme.of(context).textTheme.titleSmall,
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
        child: Text(
          'These people signed up but have not confirmed yet. Discarding a '
          'registration makes its emailed link stop working; the person may '
          'sign up again.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
      if (loaded.discardFailure case final failure?)
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: ErrorBanner(failure: failure),
        ),
      if (loaded.notice case final notice?)
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Notice(notice, icon: Icons.check_circle_outline),
        ),
      Expanded(
        child: loaded.page.items.isEmpty
            // AF-35a.
            ? const CollectionEmpty(
                title: 'No pending registrations.',
                message:
                    'Nobody is waiting to confirm a sign-up for this scope.',
                icon: Icons.how_to_reg_outlined,
              )
            : AdaptiveCollection<PendingRegistration>(
                items: loaded.page.items,
                busy: loaded.busy,
                pageNumber: loaded.page.pageNumber,
                totalPages: loaded.page.totalPages,
                totalItems: loaded.page.totalItems,
                onPageChanged: _controller.goToPage,
                title: (registration) => registration.name,
                subtitle: (registration) => registration.email,
                columns: _columns(context, busy: loaded.busy),
              ),
      ),
    ],
  );

  List<CollectionColumn<PendingRegistration>> _columns(
    BuildContext context, {
    required bool busy,
  }) {
    String when(DateTime? at) => at == null ? '—' : formatDateTime(context, at);

    return <CollectionColumn<PendingRegistration>>[
      // Beside the name it acts on rather than at the far end: the dates are
      // wide, and a last column starts off-screen on a medium window.
      CollectionColumn<PendingRegistration>(
        label: 'Discard',
        cell: (registration) => IconButton(
          icon: const Icon(Icons.delete_outline),
          tooltip: 'Discard the registration for ${registration.email}',
          // Held while a discard or a page is in flight.
          onPressed: busy ? null : () => _confirmDiscard(registration),
        ),
      ),
      CollectionColumn<PendingRegistration>(
        label: 'Signed up',
        cell: (registration) => Text(when(registration.createdAt)),
      ),
      CollectionColumn<PendingRegistration>(
        label: 'Expires',
        cell: (registration) => Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            Text(when(registration.expiresAt)),
            if (registration.expired)
              Chip(
                label: const Text('Expired'),
                backgroundColor: Theme.of(context).colorScheme.errorContainer,
              ),
          ],
        ),
      ),
      CollectionColumn<PendingRegistration>(
        label: 'Attempts left',
        cell: (registration) => Text('${registration.attemptsLeft}'),
      ),
    ];
  }
}
