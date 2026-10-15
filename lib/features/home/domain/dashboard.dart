import '../../scopes/domain/scope.dart';

/// One scope on the home dashboard, with how much it holds.
///
/// Each count is read on its own, and a count that could not be read is
/// `null` rather than zero: "none" and "unknown" are different answers, and
/// the dashboard says which one it has.
class ScopeSummary {
  const ScopeSummary({
    required this.scope,
    this.persons,
    this.applications,
    this.permissions,
    this.googleUsers,
  });

  final Scope scope;

  /// The scope's Users. Its owners are on [scope] already.
  final int? persons;
  final int? applications;
  final int? permissions;
  final int? googleUsers;
}

/// What the home dashboard shows an administrator.
class DashboardStats {
  const DashboardStats({
    required this.activeScopes,
    required this.scopes,
    this.deletedScopes,
    this.apiReachable,
    this.systemAdmins,
  });

  /// How many scopes the caller can see that are not deleted — every scope
  /// for a System Admin, the owned ones for a Scope Admin.
  final int activeScopes;

  /// How many of the caller's scopes are logically deleted, or `null` when
  /// that could not be read.
  final int? deletedScopes;

  /// The scopes the totals below are summed over, at most
  /// [DashboardStats.summarisedScopeLimit] of them.
  final List<ScopeSummary> scopes;

  /// Whether the API answered its liveness check, or `null` when nobody asked.
  final bool? apiReachable;

  /// How many scopes the dashboard breaks down. The counts cost a request per
  /// scope and kind, so a system with many scopes is summarised over the
  /// first few rather than flooding the API from the home screen.
  /// How many System Admins the system has (UI-38), or `null` when that could
  /// not be read or the caller is not a System Admin and was never told.
  final int? systemAdmins;

  static const int summarisedScopeLimit = 10;

  /// Whether the totals cover fewer scopes than the caller has.
  bool get isPartial => scopes.length < activeScopes;

  int? get persons => _sum((summary) => summary.persons);
  int? get applications => _sum((summary) => summary.applications);
  int? get permissions => _sum((summary) => summary.permissions);
  int? get googleUsers => _sum((summary) => summary.googleUsers);

  /// How many scopes have Google Sign-In switched on, of [scopes].
  int get googleSignInScopes =>
      scopes.where((summary) => summary.scope.googleSignInEnabled).length;

  /// The sum of one count across [scopes], or `null` when any of them could
  /// not be read — a total that silently left a scope out would be wrong.
  int? _sum(int? Function(ScopeSummary summary) count) {
    var total = 0;

    for (final summary in scopes) {
      final value = count(summary);

      if (value == null) {
        return null;
      }

      total += value;
    }

    return total;
  }
}
