import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:heimdall_ui/features/home/presentation/dashboard_controller.dart';

/// A dashboard controller that counts how often it was marked stale, so a
/// test of a command can say whether it told Home its figures moved.
class StaleSpyDashboardController extends DashboardController {
  int marks = 0;

  @override
  void markStale() {
    marks++;
    super.markStale();
  }
}

/// Swaps the dashboard for the spy; read the count with [staleMarksOf].
Override staleSpyOverride() =>
    dashboardControllerProvider.overrideWith(StaleSpyDashboardController.new);

/// How often Home was marked stale in [container].
int staleMarksOf(ProviderContainer container) => (container.read(
  dashboardControllerProvider.notifier,
) as StaleSpyDashboardController).marks;
