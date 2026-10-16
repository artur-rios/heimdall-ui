import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/core/result/result.dart';
import 'package:heimdall_ui/core/storage/token_store.dart';
import 'package:heimdall_ui/features/auth/presentation/session_controller.dart';
import 'package:heimdall_ui/features/home/domain/dashboard.dart';
import 'package:heimdall_ui/features/home/presentation/dashboard_controller.dart';
import 'package:heimdall_ui/features/scopes/domain/scope.dart';

import '../../support/dashboard_fakes.dart';
import '../../support/late_answer.dart';

/// A token naming a person of [role]: 1 System Admin, 2 Scope Admin, 3 User.
String _jwt(int role) {
  final payload = base64Url.encode(
    utf8.encode(
      jsonEncode(<String, dynamic>{
        'sub': 'person-1',
        'name': 'Ada',
        'role': role,
      }),
    ),
  );

  return 'header.$payload.signature';
}

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

  /// Loads the dashboard as a person of [role].
  Future<DashboardState> loadAs(
    int role,
    FakeDashboardRepositories fakes,
  ) async {
    final store = InMemoryTokenStore();
    await store.write(
      AuthToken(value: _jwt(role), expiresAt: DateTime.utc(2030)),
    );
    final container = ProviderContainer(
      overrides: <Override>[
        ...fakes.overrides,
        tokenStoreProvider.overrideWithValue(store),
      ],
    );
    addTearDown(container.dispose);
    await container.read(sessionControllerProvider.notifier).restore();

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

  test('GivenASystemAdmin_WhenLoaded_ThenTheSystemAdminCountIsRead', () async {
    // Given
    final fakes = FakeDashboardRepositories(systemAdmins: 3);

    // When
    final state = await loadAs(1, fakes);

    // Then
    expect((state as DashboardLoaded).stats.systemAdmins, 3);
    expect(fakes.systemAdminsReads, 1);
  });

  test('GivenASystemAdminCountThatFails_WhenLoaded_ThenItIsUnknown', () async {
    // Given
    final fakes = FakeDashboardRepositories(systemAdmins: null);

    // When
    final state = await loadAs(1, fakes);

    // Then
    expect(state, isA<DashboardLoaded>());
    expect((state as DashboardLoaded).stats.systemAdmins, isNull);
  });

  test('GivenAScopeAdmin_WhenLoaded_ThenTheSystemAdminsAreNotAsked', () async {
    // Given
    final fakes = FakeDashboardRepositories(systemAdmins: 3);

    // When
    final state = await loadAs(2, fakes);

    // Then
    expect((state as DashboardLoaded).stats.systemAdmins, isNull);
    expect(fakes.systemAdminsReads, 0);
  });

  test(
    'GivenASupersededLoad_WhenItsCountArrivesLate_ThenTheNewerFiguresStay',
    () async {
      // Given — load 1 is held on its System Admins count
      final held = Completer<int?>();
      final fakes = FakeDashboardRepositories(
        systemAdminsAnswer: (read) async => read == 1 ? held.future : 5,
      );
      final store = InMemoryTokenStore();
      await store.write(
        AuthToken(value: _jwt(1), expiresAt: DateTime.utc(2030)),
      );
      final container = ProviderContainer(
        overrides: <Override>[
          ...fakes.overrides,
          tokenStoreProvider.overrideWithValue(store),
        ],
      );
      addTearDown(container.dispose);
      await container.read(sessionControllerProvider.notifier).restore();
      final notifier = container.read(dashboardControllerProvider.notifier);
      final first = notifier.load();
      await Future<void>.delayed(Duration.zero);

      // When — load 2 finishes first, then load 1's count arrives
      await notifier.load();
      held.complete(3);
      await first;

      // Then
      final state = container.read(dashboardControllerProvider);
      expect((state as DashboardLoaded).stats.systemAdmins, 5);
    },
  );

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

  // A sign-out resets the dashboard while a load is in flight, and the late
  // figures, the previous session's, must not land in the reset state.
  test(
    'GivenALoadInFlight_WhenTheSessionResets_ThenTheFiguresAreDropped',
    () async {
      // Given
      final held = Completer<int?>();
      final fakes = FakeDashboardRepositories(
        scopes: const <Scope>[_acme],
        systemAdminsAnswer: (_) => held.future,
      );
      final store = InMemoryTokenStore();
      await store.write(
        AuthToken(value: _jwt(1), expiresAt: DateTime.utc(2030)),
      );
      final container = ProviderContainer(
        overrides: <Override>[
          ...fakes.overrides,
          tokenStoreProvider.overrideWithValue(store),
        ],
      );
      addTearDown(container.dispose);
      await container.read(sessionControllerProvider.notifier).restore();
      final notifier = container.read(dashboardControllerProvider.notifier);

      // When
      await answerAfterReset(
        container,
        dashboardControllerProvider,
        reset: dashboardControllerProvider,
        start: notifier.load,
        answer: () => held.complete(3),
      );

      // Then
      expect(
        container.read(dashboardControllerProvider),
        isA<DashboardLoading>(),
      );
    },
  );
}
