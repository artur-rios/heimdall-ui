import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/envelope.dart';
import '../../../core/result/result.dart';
import '../../../core/time/clock.dart';
import '../../applications/domain/application_repository.dart';
import '../../auth/domain/session.dart';
import '../../auth/presentation/session_controller.dart';
import '../../google_users/domain/google_user_repository.dart';
import '../../health/domain/health_repository.dart';
import '../../permissions/domain/scope_permission_repository.dart';
import '../../profile/presentation/profile_controller.dart';
import '../../scopes/domain/scope.dart';
import '../../scopes/presentation/scope_list_controller.dart';
import '../domain/dashboard.dart';

/// How far the administrator's dashboard has got.
sealed class DashboardState {
  const DashboardState();
}

/// Nothing has been read yet, or a fresh read is under way with nothing to
/// show in the meantime.
final class DashboardLoading extends DashboardState {
  const DashboardLoading();
}

/// The scopes could not be read, so there is nothing to summarise.
final class DashboardFailed extends DashboardState {
  const DashboardFailed(this.failure);

  final Failure failure;
}

/// The figures are on screen. [refreshing] keeps them there while a refresh
/// is in flight, rather than blanking the dashboard for every reload.
final class DashboardLoaded extends DashboardState {
  const DashboardLoaded(this.stats, {this.refreshing = false});

  final DashboardStats stats;
  final bool refreshing;
}

final NotifierProvider<DashboardController, DashboardState>
dashboardControllerProvider =
    NotifierProvider<DashboardController, DashboardState>(
      DashboardController.new,
    );

/// Reads what the home dashboard shows an administrator.
///
/// Nothing here is a new endpoint: every figure is the `totalItems` of a
/// one-row page of a listing the administrator could open themselves, so the
/// dashboard can never show a number the API would not.
///
/// A successful load is reused for [freshFor]: Home is re-entered from almost
/// every screen, and each read costs about forty requests (#172). A command
/// that changes what Home counts calls [markStale] (through
/// `HomeDataStale.markHomeDataStale`), so Back to Home after a change still
/// re-reads inside that window.
class DashboardController extends Notifier<DashboardState> {
  /// How long a successful load is reused by a plain [load].
  static const Duration freshFor = Duration(seconds: 60);

  /// When the last successful load began, or `null` when there is none worth
  /// reusing — never loaded, reset, or marked stale since.
  DateTime? _loadedAt;

  /// Increments with every [markStale], so a load that was already in flight
  /// when the data changed does not vouch for itself as fresh.
  int _staleMarks = 0;

  /// Increments with every load, so an answer to a superseded load is dropped
  /// rather than overwriting a newer one — and with every reset, so an answer
  /// to a load of an earlier build is dropped too (see `BuildEpoch`).
  int _generation = 0;

  @override
  DashboardState build() {
    ref.onDispose(() => _generation++);
    _loadedAt = null;

    return const DashboardLoading();
  }

  /// Forgets that the last load is recent, because something it counted has
  /// changed: the next [load] reads again whatever its age.
  void markStale() {
    _staleMarks++;
    _loadedAt = null;
  }

  /// Reads the dashboard, unless the last successful read is under [freshFor]
  /// old; [force] — the explicit refresh — reads regardless.
  Future<void> load({bool force = false}) async {
    final startedAt = ref.read(clockProvider)();
    final loadedAt = _loadedAt;

    if (!force &&
        loadedAt != null &&
        state is DashboardLoaded &&
        startedAt.difference(loadedAt) < freshFor) {
      return;
    }

    final staleMarks = _staleMarks;
    final generation = ++_generation;
    final current = state;

    state = current is DashboardLoaded
        ? DashboardLoaded(current.stats, refreshing: true)
        : const DashboardLoading();

    final scopes = ref.read(scopeRepositoryProvider);
    final health = ref.read(healthRepositoryProvider);

    final active = scopes.list(pageSize: DashboardStats.summarisedScopeLimit);
    final everything = scopes.list(includeDeleted: true, pageSize: 1);
    final ping = health.ping();
    final session = ref.read(sessionControllerProvider);
    final isSystemAdmin =
        session is Authenticated && session.principal.isSystemAdmin;
    // UC-07 read (e) is a System Admin's only; nobody else is asked.
    final systemAdmins = isSystemAdmin
        ? ref.read(personRepositoryProvider).listSystemAdmins(pageSize: 1)
        : null;

    final activeResult = await active;

    if (generation != _generation) {
      return;
    }

    switch (activeResult) {
      case FailureResult<Page<Scope>>(:final failure):
        state = DashboardFailed(failure);

        return;
      case Success<Page<Scope>>(value: final page):
        final summaries = await Future.wait(page.items.map(_summarise));
        final everythingTotal = (await everything).valueOrNull?.totalItems;
        final reachable = (await ping).isSuccess;
        // Awaited before the guard: a suspension after it could let a
        // superseded load overwrite a newer one.
        final adminTotal = systemAdmins == null
            ? null
            : (await systemAdmins).valueOrNull?.totalItems;

        if (generation != _generation) {
          return;
        }

        _loadedAt = staleMarks == _staleMarks ? startedAt : null;
        state = DashboardLoaded(
          DashboardStats(
            activeScopes: page.totalItems,
            deletedScopes: everythingTotal == null
                ? null
                : (everythingTotal - page.totalItems).clamp(0, everythingTotal),
            scopes: summaries,
            apiReachable: reachable,
            systemAdmins: adminTotal,
          ),
        );
    }
  }

  /// Reads the four counts of one scope side by side.
  Future<ScopeSummary> _summarise(Scope scope) async {
    final persons = ref
        .read(personRepositoryProvider)
        .listScopePersons(scopeId: scope.id, pageSize: 1);
    final applications = ref
        .read(applicationRepositoryProvider)
        .list(scopeId: scope.id, pageSize: 1);
    final permissions = ref
        .read(scopePermissionRepositoryProvider)
        .list(scopeId: scope.id, pageSize: 1);
    final googleUsers = ref
        .read(googleUserRepositoryProvider)
        .countIn(scope.id);

    return ScopeSummary(
      scope: scope,
      persons: (await persons).valueOrNull?.totalItems,
      applications: (await applications).valueOrNull?.totalItems,
      permissions: (await permissions).valueOrNull?.totalItems,
      googleUsers: (await googleUsers).valueOrNull,
    );
  }
}

/// What a command that changes Home's figures calls on success.
extension HomeDataStale on Ref {
  /// Makes the next Home load read again rather than reuse a recent one.
  void markHomeDataStale() =>
      read(dashboardControllerProvider.notifier).markStale();
}
