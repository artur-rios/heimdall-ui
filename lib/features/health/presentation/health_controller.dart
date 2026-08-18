import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/result/result.dart';
import '../domain/health.dart';
import '../domain/health_repository.dart';

/// What the health screen knows.
///
/// The two checks are independent: the liveness one anybody may call, the
/// detailed one only a System Admin may. Either can answer while the other
/// does not, and the screen shows whichever it has.
class HealthState {
  const HealthState({
    this.checking = false,
    this.liveness,
    this.livenessFailure,
    this.detailed,
    this.detailedFailure,
  });

  /// Both checks are in flight. The refresh control is disabled while they
  /// are, so a fast second tap cannot double the requests.
  final bool checking;

  /// What the liveness check answered with.
  final String? liveness;
  final Failure? livenessFailure;

  final Health? detailed;
  final Failure? detailedFailure;

  /// Whether the detailed report was refused because of who is asking, which
  /// is the expected answer for a Scope Admin rather than a fault.
  bool get detailedForbidden =>
      detailedFailure?.kind == FailureKind.forbidden ||
      detailedFailure?.kind == FailureKind.unauthorized;

  /// Whether anything has been asked for yet.
  bool get isEmpty =>
      liveness == null &&
      livenessFailure == null &&
      detailed == null &&
      detailedFailure == null;
}

final NotifierProvider<HealthController, HealthState> healthControllerProvider =
    NotifierProvider<HealthController, HealthState>(HealthController.new);

/// Owns the two health checks and the refresh that repeats them.
class HealthController extends Notifier<HealthState> {
  @override
  HealthState build() => const HealthState();

  /// Runs both checks.
  ///
  /// They go together rather than in sequence: neither depends on the other,
  /// and an operator asking "is it up" wants both answers at once.
  Future<void> check() async {
    if (state.checking) {
      return;
    }

    state = HealthState(checking: true, liveness: state.liveness);

    final repository = ref.read(healthRepositoryProvider);
    final results = await Future.wait<Object>(<Future<Object>>[
      repository.ping(),
      repository.detailed(),
    ]);

    final liveness = results[0] as Result<String>;
    final detailed = results[1] as Result<Health>;

    state = HealthState(
      liveness: liveness.valueOrNull,
      livenessFailure: liveness.failureOrNull,
      detailed: detailed.valueOrNull,
      detailedFailure: detailed.failureOrNull,
    );
  }
}
