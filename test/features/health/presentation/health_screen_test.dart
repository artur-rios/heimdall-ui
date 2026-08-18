import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/app/theme.dart';
import 'package:heimdall_ui/core/result/result.dart';
import 'package:heimdall_ui/core/storage/token_store.dart';
import 'package:heimdall_ui/features/auth/presentation/session_controller.dart';
import 'package:heimdall_ui/features/health/domain/health.dart';
import 'package:heimdall_ui/features/health/domain/health_repository.dart';
import 'package:heimdall_ui/features/health/presentation/health_screen.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockHealthRepository extends Mock implements HealthRepository {}

/// A token naming a person of [role]: 1 System Admin, 2 Scope Admin.
String _jwt({int role = 1}) {
  final payload = base64Url.encode(
    utf8.encode(
      jsonEncode(<String, dynamic>{
        'sub': 'person-9',
        'email': 'admin@example.com',
        'role': role,
      }),
    ),
  );

  return 'header.$payload.signature';
}

const _healthy = Health(
  status: 'Healthy',
  services: <ServiceHealth>[
    ServiceHealth(name: 'Database', status: 'Healthy'),
    ServiceHealth(name: 'Mail', status: 'Healthy'),
  ],
);

const _unhealthy = Health(
  status: 'Unhealthy',
  services: <ServiceHealth>[
    ServiceHealth(name: 'Database', status: 'Healthy'),
    ServiceHealth(name: 'Mail', status: 'Unhealthy'),
  ],
);

const Size _compact = Size(400, 900);
const Size _medium = Size(800, 900);
const Size _expanded = Size(1400, 900);

void main() {
  late _MockHealthRepository repository;
  late InMemoryTokenStore store;
  late ProviderContainer container;

  Future<void> pump(
    WidgetTester tester, {
    Size size = _expanded,
    ThemeData? theme,
    int role = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await store.write(
      AuthToken(
        value: _jwt(role: role),
        expiresAt: DateTime.utc(2030),
      ),
    );

    container = ProviderContainer(
      overrides: <Override>[
        healthRepositoryProvider.overrideWithValue(repository),
        tokenStoreProvider.overrideWithValue(store),
      ],
    );
    addTearDown(container.dispose);
    await container.read(sessionControllerProvider.notifier).restore();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: theme ?? buildLightTheme(),
          home: const HealthScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  void answerPingWith(Result<String> result) {
    when(() => repository.ping()).thenAnswer((_) async => result);
  }

  void answerDetailedWith(Result<Health> result) {
    when(() => repository.detailed()).thenAnswer((_) async => result);
  }

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    repository = _MockHealthRepository();
    store = InMemoryTokenStore();
    answerPingWith(const Success<String>('Hello, world!'));
    answerDetailedWith(const Success<Health>(_healthy));
  });

  testWidgets('GivenAReachableApi_WhenOpened_ThenItSaysSo', (tester) async {
    // Given / When
    await pump(tester);

    // Then
    expect(find.text('The API is reachable'), findsOneWidget);
    expect(find.text('Hello, world!'), findsOneWidget);
  });

  testWidgets('GivenAnUnreachableApi_WhenOpened_ThenItSaysSo', (tester) async {
    // Given
    answerPingWith(
      const FailureResult<String>(
        Failure(
          kind: FailureKind.network,
          errors: <String>[],
          message: 'Connection refused',
        ),
      ),
    );
    answerDetailedWith(
      const FailureResult<Health>(
        Failure(kind: FailureKind.network, errors: <String>[]),
      ),
    );

    // When
    await pump(tester);

    // Then
    expect(find.text('The API did not answer'), findsOneWidget);
    expect(find.text('Connection refused'), findsOneWidget);
  });

  testWidgets('GivenAHealthyApi_WhenOpened_ThenEveryServiceIsListed', (
    tester,
  ) async {
    // Given / When
    await pump(tester);

    // Then
    expect(find.text('Database'), findsOneWidget);
    expect(find.text('Mail'), findsOneWidget);
    expect(find.textContaining('Every checked service'), findsOneWidget);
  });

  testWidgets('GivenAnUnhealthyService_WhenOpened_ThenTheCountIsGiven', (
    tester,
  ) async {
    // Given
    answerDetailedWith(const Success<Health>(_unhealthy));

    // When
    await pump(tester);

    // Then
    expect(
      find.textContaining('1 of 2 services are not healthy'),
      findsOneWidget,
    );
  });

  // The API's own word is what is shown, whatever it is.
  testWidgets('GivenAnUnfamiliarStatus_WhenOpened_ThenItIsShownAsGiven', (
    tester,
  ) async {
    // Given
    answerDetailedWith(
      const Success<Health>(
        Health(
          status: 'Degraded',
          services: <ServiceHealth>[
            ServiceHealth(name: 'Mail', status: 'Degraded'),
          ],
        ),
      ),
    );

    // When
    await pump(tester);

    // Then
    expect(find.text('Degraded'), findsNWidgets(2));
  });

  // A Scope Admin is offered the screen but refused the detailed report, and
  // that is the expected answer rather than a fault.
  testWidgets('GivenAScopeAdmin_WhenRefused_ThenTheReasonIsExplained', (
    tester,
  ) async {
    // Given
    answerDetailedWith(
      const FailureResult<Health>(
        Failure(kind: FailureKind.forbidden, errors: <String>[]),
      ),
    );

    // When
    await pump(tester, role: 2);

    // Then
    expect(find.textContaining('only shown to a System Admin'), findsOneWidget);
  });

  testWidgets('GivenAScopeAdmin_WhenRefused_ThenTheLivenessStillShows', (
    tester,
  ) async {
    // Given
    answerDetailedWith(
      const FailureResult<Health>(
        Failure(kind: FailureKind.forbidden, errors: <String>[]),
      ),
    );

    // When
    await pump(tester, role: 2);

    // Then
    expect(find.text('The API is reachable'), findsOneWidget);
  });

  testWidgets('GivenARefusedReport_WhenOpened_ThenApiErrorsAreShown', (
    tester,
  ) async {
    // Given
    answerDetailedWith(
      const FailureResult<Health>(
        Failure(
          kind: FailureKind.server,
          errors: <String>['The health check itself failed.'],
        ),
      ),
    );

    // When
    await pump(tester);

    // Then
    expect(find.text('The health check itself failed.'), findsOneWidget);
  });

  testWidgets('GivenTheScreen_WhenRefreshTapped_ThenBothChecksRunAgain', (
    tester,
  ) async {
    // Given
    await pump(tester);

    // When
    await tester.tap(find.byTooltip('Check again'));
    await tester.pumpAndSettle();

    // Then
    verify(() => repository.ping()).called(2);
    verify(() => repository.detailed()).called(2);
  });

  testWidgets('GivenNoServices_WhenOpened_ThenItSaysNoneWereReported', (
    tester,
  ) async {
    // Given
    answerDetailedWith(const Success<Health>(Health(status: 'Healthy')));

    // When
    await pump(tester);

    // Then
    expect(
      find.text('The API reported no individual services.'),
      findsOneWidget,
    );
  });

  testWidgets('GivenACompactWindow_WhenRendered_ThenTheReportIsShown', (
    tester,
  ) async {
    // Given / When
    await pump(tester, size: _compact);

    // Then
    expect(find.text('The API is reachable'), findsOneWidget);
  });

  testWidgets('GivenAMediumWindow_WhenRendered_ThenTheReportIsShown', (
    tester,
  ) async {
    // Given / When
    await pump(tester, size: _medium);

    // Then
    expect(find.text('The API is reachable'), findsOneWidget);
  });

  testWidgets('GivenTheDarkTheme_WhenRendered_ThenTheReportIsStillShown', (
    tester,
  ) async {
    // Given / When
    await pump(tester, theme: buildDarkTheme());

    // Then
    expect(find.text('The API is reachable'), findsOneWidget);
  });
}
