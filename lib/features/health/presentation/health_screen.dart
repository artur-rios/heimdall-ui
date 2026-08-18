import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/result/result.dart';
import '../../../shared/layout/app_shell.dart';
import '../../../shared/widgets/failure_banner.dart';
import 'health_controller.dart';

/// P-04 — whether the API is up, and what it says about itself.
class HealthScreen extends ConsumerStatefulWidget {
  const HealthScreen({super.key});

  @override
  ConsumerState<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends ConsumerState<HealthScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(healthControllerProvider.notifier).check(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(healthControllerProvider);

    return AppShell(
      currentRoute: '/health',
      title: const Text('Health'),
      actions: <Widget>[
        IconButton(
          tooltip: 'Check again',
          icon: const Icon(Icons.refresh),
          onPressed: state.checking
              ? null
              : () => ref.read(healthControllerProvider.notifier).check(),
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: <Widget>[
          if (state.checking && state.isEmpty)
            const LinearProgressIndicator()
          else ...<Widget>[
            _LivenessCard(
              answer: state.liveness,
              failure: state.livenessFailure,
            ),
            const SizedBox(height: 16),
            Text('Services', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            _DetailedSection(state: state),
          ],
        ],
      ),
    );
  }
}

/// The check anybody may make: did the API answer at all.
class _LivenessCard extends StatelessWidget {
  const _LivenessCard({required this.answer, required this.failure});

  final String? answer;
  final Failure? failure;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reachable = answer != null;

    return Card(
      color: reachable
          ? theme.colorScheme.secondaryContainer
          : theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: <Widget>[
            Icon(
              reachable ? Icons.check_circle_outline : Icons.cloud_off_outlined,
              color: reachable
                  ? theme.colorScheme.onSecondaryContainer
                  : theme.colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    reachable
                        ? 'The API is reachable'
                        : 'The API did not answer',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: reachable
                          ? theme.colorScheme.onSecondaryContainer
                          : theme.colorScheme.onErrorContainer,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    answer ?? failure?.displayMessage ?? 'No answer.',
                    style: TextStyle(
                      color: reachable
                          ? theme.colorScheme.onSecondaryContainer
                          : theme.colorScheme.onErrorContainer,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The detailed report, which the API gives only to a System Admin.
class _DetailedSection extends StatelessWidget {
  const _DetailedSection({required this.state});

  final HealthState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // A Scope Admin is offered this screen read-only, and the API's refusal of
    // the detailed report is the expected answer rather than a fault.
    if (state.detailedForbidden) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'The per-service report is only shown to a System Admin. The '
            'reachability check above is what your role is given.',
            style: theme.textTheme.bodyMedium,
          ),
        ),
      );
    }

    if (state.detailedFailure case final failure?) {
      return ErrorBanner(failure: failure);
    }

    final health = state.detailed;

    if (health == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('No report yet.', style: theme.textTheme.bodyMedium),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Card(
          child: ListTile(
            leading: _StatusChip(status: health.status),
            title: const Text('Overall'),
            subtitle: Text(
              health.unhealthy.isEmpty
                  ? 'Every checked service reported healthy.'
                  : '${health.unhealthy.length} of ${health.services.length} '
                        'services are not healthy.',
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (health.services.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'The API reported no individual services.',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          )
        else
          Card(
            child: Column(
              children: <Widget>[
                for (final service in health.services)
                  ListTile(
                    leading: _StatusChip(status: service.status),
                    title: Text(service.name),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// A status as the API worded it, coloured by whether it reads as healthy.
///
/// The word is never rewritten: a state this does not recognise is shown as it
/// came rather than being called a failure.
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final healthy = status.toLowerCase() == 'healthy';

    return Chip(
      avatar: Icon(
        healthy ? Icons.check_circle_outline : Icons.error_outline,
        color: healthy ? scheme.onSecondaryContainer : scheme.onErrorContainer,
      ),
      label: Text(status),
      backgroundColor: healthy
          ? scheme.secondaryContainer
          : scheme.errorContainer,
      labelStyle: TextStyle(
        color: healthy ? scheme.onSecondaryContainer : scheme.onErrorContainer,
      ),
    );
  }
}
