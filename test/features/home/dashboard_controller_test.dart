import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/core/result/result.dart';
import 'package:heimdall_ui/features/home/domain/dashboard.dart';
import 'package:heimdall_ui/features/home/presentation/dashboard_controller.dart';
import 'package:heimdall_ui/features/scopes/domain/scope.dart';

import '../../support/dashboard_fakes.dart';

const _acme = Scope(
  id: 'scope-1',
  name: 'Acme',
  description: 'First tenant',
  googleSignInEnabled: true,
);

const _globex = Scope(id: 'scope-2', name: 'Globex', description: '');

void main() {
  Future<DashboardState> load(FakeDashboardRepositories fakes) async {
    final container = ProviderContainer(overrides: fakes.overrides);
    addTearDown(container.dispose);

    await container.read(dashboardControllerProvider.notifier).load();

    return container.read(dashboardControllerProvider);
  }

  test('GivenNothingLoaded_WhenBuilt_ThenStateIsLoading', () {
    // Given
    final container = ProviderContainer(
      overrides: FakeDashboardRepositories().overrides,
    );
    addTearDown(container.dispose);

    // When
    final state = container.read(dashboardControllerProvider);

    // Then
    expect(state, isA<DashboardLoading>());
  });

  test('GivenTwoScopes_WhenLoaded_ThenTheCountsAreSummed', () async {
    // Given
    final fakes = FakeDashboardRepositories(
      scopes: const <Scope>[_acme, _globex],
      deletedScopes: 3,
      persons: 4,
      applications: 2,
      permissions: 5,
      googleUsers: 1,
    );

    // When
    final state = await load(fakes);

    // Then
    final stats = (state as DashboardLoaded).stats;
    expect(stats.activeScopes, 2);
    expect(stats.deletedScopes, 3);
    expect(stats.persons, 8);
    expect(stats.applications, 4);
    expect(stats.permissions, 10);
    expect(stats.googleUsers, 2);
    expect(stats.googleSignInScopes, 1);
    expect(stats.apiReachable, isTrue);
    expect(stats.isPartial, isFalse);
  });

  // A total that quietly left a scope out would be wrong, so a count that
  // could not be read makes the total unknown rather than smaller.
  test('GivenAnUnreadableCount_WhenLoaded_ThenTheTotalIsUnknown', () async {
    // Given
    final fakes = FakeDashboardRepositories(
      scopes: const <Scope>[_acme],
      applications: null,
    );

    // When
    final state = await load(fakes);

    // Then
    final stats = (state as DashboardLoaded).stats;
    expect(stats.applications, isNull);
    expect(stats.scopes.single.applications, isNull);
    expect(stats.persons, 0);
  });

  test('GivenMoreScopesThanSummarised_WhenLoaded_ThenItIsPartial', () async {
    // Given
    final fakes = FakeDashboardRepositories(
      scopes: const <Scope>[_acme, _globex],
      activeTotal: 40,
    );

    // When
    final state = await load(fakes);

    // Then
    final stats = (state as DashboardLoaded).stats;
    expect(stats.activeScopes, 40);
    expect(stats.isPartial, isTrue);
  });

  test('GivenUnreadableScopes_WhenLoaded_ThenTheFailureIsKept', () async {
    // Given
    const failure = Failure(
      kind: FailureKind.server,
      errors: <String>['Scopes are unavailable.'],
    );
    final fakes = FakeDashboardRepositories(scopesFailure: failure);

    // When
    final state = await load(fakes);

    // Then
    expect((state as DashboardFailed).failure, same(failure));
  });

  test('GivenAnUnreachableApi_WhenLoaded_ThenItIsSaidToBeDown', () async {
    // Given
    final fakes = FakeDashboardRepositories(apiReachable: false);

    // When
    final state = await load(fakes);

    // Then
    expect((state as DashboardLoaded).stats.apiReachable, isFalse);
  });

  test('GivenLoadedFigures_WhenRefreshed_ThenTheyStayOnScreen', () async {
    // Given
    final container = ProviderContainer(
      overrides: FakeDashboardRepositories(scopes: const <Scope>[_acme])
          .overrides,
    );
    addTearDown(container.dispose);
    final controller = container.read(dashboardControllerProvider.notifier);
    await controller.load();

    // When
    final refresh = controller.load();
    final during = container.read(dashboardControllerProvider);
    await refresh;

    // Then
    expect(during, isA<DashboardLoaded>());
    expect((during as DashboardLoaded).refreshing, isTrue);
    expect(
      (container.read(
        dashboardControllerProvider,
      ) as DashboardLoaded).refreshing,
      isFalse,
    );
  });

  test('GivenNoScopes_WhenSummed_ThenEveryTotalIsZero', () {
    // Given
    const stats = DashboardStats(activeScopes: 0, scopes: <ScopeSummary>[]);

    // When
    final totals = <int?>[
      stats.persons,
      stats.applications,
      stats.permissions,
      stats.googleUsers,
    ];

    // Then
    expect(totals, everyElement(0));
    expect(stats.isPartial, isFalse);
  });
}
