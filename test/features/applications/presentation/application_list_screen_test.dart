import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:heimdall_ui/app/theme.dart';
import 'package:heimdall_ui/core/network/envelope.dart' as envelope;
import 'package:heimdall_ui/core/result/result.dart';
import 'package:heimdall_ui/core/storage/token_store.dart';
import 'package:heimdall_ui/features/applications/domain/application.dart';
import 'package:heimdall_ui/features/applications/domain/application_repository.dart';
import 'package:heimdall_ui/features/applications/presentation/application_list_screen.dart';
import 'package:heimdall_ui/features/auth/domain/session.dart';
import 'package:heimdall_ui/features/auth/presentation/session_controller.dart';
import 'package:heimdall_ui/features/persons/domain/person.dart';
import 'package:heimdall_ui/features/persons/domain/person_repository.dart';
import 'package:heimdall_ui/features/profile/presentation/profile_controller.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockApplicationRepository extends Mock
    implements ApplicationRepository {}

class _MockPersonRepository extends Mock implements PersonRepository {}

String _jwt() {
  final payload = base64Url.encode(
    utf8.encode(
      jsonEncode(<String, dynamic>{
        'sub': 'person-9',
        'email': 'admin@example.com',
        'role': 1,
      }),
    ),
  );

  return 'header.$payload.signature';
}

const _billing = Application(id: 'app-1', name: 'Billing', ownerId: 'person-1');

const _ada = Person(
  id: 'person-1',
  name: 'Ada',
  email: 'ada@example.com',
  role: Role.user,
);

envelope.Page<Application> _page({
  List<Application> items = const <Application>[_billing],
  int pageNumber = 1,
  int totalPages = 1,
}) => envelope.Page<Application>(
  items: items,
  pageNumber: pageNumber,
  pageSize: 20,
  totalItems: items.length,
  totalPages: totalPages,
);

const Size _compact = Size(400, 900);
const Size _medium = Size(800, 900);
const Size _expanded = Size(1400, 900);

void main() {
  late _MockApplicationRepository applications;
  late _MockPersonRepository persons;
  late InMemoryTokenStore store;
  late ProviderContainer container;
  late GoRouter router;

  Future<void> pump(
    WidgetTester tester, {
    Size size = _expanded,
    ThemeData? theme,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await store.write(AuthToken(value: _jwt(), expiresAt: DateTime.utc(2030)));

    container = ProviderContainer(
      overrides: <Override>[
        applicationRepositoryProvider.overrideWithValue(applications),
        personRepositoryProvider.overrideWithValue(persons),
        tokenStoreProvider.overrideWithValue(store),
      ],
    );
    addTearDown(container.dispose);
    await container.read(sessionControllerProvider.notifier).restore();

    router = GoRouter(
      initialLocation: '/scopes/scope-1/applications',
      routes: <RouteBase>[
        GoRoute(
          path: '/scopes',
          builder: (context, state) => const Scaffold(body: Text('scopes')),
        ),
        GoRoute(
          path: '/scopes/:scopeId',
          builder: (context, state) => const Scaffold(body: Text('scope')),
        ),
        GoRoute(
          path: '/scopes/:scopeId/applications',
          builder: (context, state) =>
              ApplicationListScreen(scopeId: state.pathParameters['scopeId']!),
        ),
        GoRoute(
          path: '/scopes/:scopeId/applications/new',
          builder: (context, state) => const Scaffold(body: Text('create')),
        ),
        GoRoute(
          path: '/scopes/:scopeId/applications/:applicationId',
          builder: (context, state) => Scaffold(
            body: Text('detail ${state.pathParameters['applicationId']}'),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: theme ?? buildLightTheme(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  void answerWith(Result<envelope.Page<Application>> result) {
    when(
      () => applications.list(
        scopeId: any(named: 'scopeId'),
        name: any(named: 'name'),
        ownerId: any(named: 'ownerId'),
        includeDeleted: any(named: 'includeDeleted'),
        pageNumber: any(named: 'pageNumber'),
        pageSize: any(named: 'pageSize'),
      ),
    ).thenAnswer((_) async => result);
  }

  void answerOwnerWith(Result<Person> result) {
    when(
      () =>
          persons.getById(any(), includeDeleted: any(named: 'includeDeleted')),
    ).thenAnswer((_) async => result);
  }

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    applications = _MockApplicationRepository();
    persons = _MockPersonRepository();
    store = InMemoryTokenStore();
    answerOwnerWith(const Success<Person>(_ada));
  });

  testWidgets('GivenAPage_WhenOpened_ThenTheApplicationsAreListed', (
    tester,
  ) async {
    // Given
    answerWith(Success<envelope.Page<Application>>(_page()));

    // When
    await pump(tester);

    // Then
    expect(find.text('Billing'), findsOneWidget);
  });

  // FR-AP-08 — the owner is shown by name.
  testWidgets('GivenAResolvableOwner_WhenListed_ThenTheirNameIsShown', (
    tester,
  ) async {
    // Given
    answerWith(Success<envelope.Page<Application>>(_page()));

    // When
    await pump(tester);

    // Then
    expect(find.text('Ada'), findsOneWidget);
  });

  // AF-20d — an owner that cannot be resolved is shown by its identifier.
  testWidgets('GivenAnUnresolvableOwner_WhenListed_ThenTheIdentifierIsShown', (
    tester,
  ) async {
    // Given
    answerWith(Success<envelope.Page<Application>>(_page()));
    answerOwnerWith(
      const FailureResult<Person>(
        Failure(kind: FailureKind.notFound, errors: <String>[]),
      ),
    );

    // When
    await pump(tester);

    // Then
    expect(find.text('person-1'), findsOneWidget);
  });

  // FR-UX-04 — a table when the window is wide, cards when it is not.
  testWidgets('GivenAnExpandedWindow_WhenListed_ThenATableIsShown', (
    tester,
  ) async {
    // Given
    answerWith(Success<envelope.Page<Application>>(_page()));

    // When
    await pump(tester, size: _expanded);

    // Then
    expect(find.byType(DataTable), findsOneWidget);
  });

  testWidgets('GivenAMediumWindow_WhenListed_ThenATableIsShown', (
    tester,
  ) async {
    // Given
    answerWith(Success<envelope.Page<Application>>(_page()));

    // When
    await pump(tester, size: _medium);

    // Then
    expect(find.byType(DataTable), findsOneWidget);
  });

  testWidgets('GivenACompactWindow_WhenListed_ThenCardsAreShown', (
    tester,
  ) async {
    // Given
    answerWith(Success<envelope.Page<Application>>(_page()));

    // When
    await pump(tester, size: _compact);

    // Then
    expect(find.byType(DataTable), findsNothing);
    expect(find.byType(Card), findsOneWidget);
  });

  testWidgets('GivenAnApplication_WhenTapped_ThenItsDetailOpens', (
    tester,
  ) async {
    // Given
    answerWith(Success<envelope.Page<Application>>(_page()));
    await pump(tester, size: _compact);

    // When
    await tester.tap(find.text('Billing'));
    await tester.pumpAndSettle();

    // Then
    expect(find.text('detail app-1'), findsOneWidget);
  });

  // AF-20a — none yet, which offers UI-21.
  testWidgets('GivenNoneAndNoFilter_WhenListed_ThenCreateIsOffered', (
    tester,
  ) async {
    // Given
    answerWith(
      Success<envelope.Page<Application>>(_page(items: const <Application>[])),
    );

    // When
    await pump(tester);

    // Then
    expect(find.text('No applications yet'), findsOneWidget);
  });

  // AF-20a — no matches, which offers to clear the filter.
  testWidgets('GivenNoMatches_WhenSearched_ThenClearingIsOffered', (
    tester,
  ) async {
    // Given
    answerWith(
      Success<envelope.Page<Application>>(_page(items: const <Application>[])),
    );
    await pump(tester);

    // When
    await tester.enterText(find.byType(TextField), 'nothing');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    // Then
    expect(find.text('No applications matched'), findsOneWidget);
  });

  // AF-20b — the returned errors, with a retry.
  testWidgets('GivenARefusedListing_WhenOpened_ThenApiErrorsAreShown', (
    tester,
  ) async {
    // Given
    answerWith(
      const FailureResult<envelope.Page<Application>>(
        Failure(
          kind: FailureKind.validation,
          errors: <String>['Page size is too large.'],
        ),
      ),
    );

    // When
    await pump(tester);

    // Then
    expect(find.text('Page size is too large.'), findsOneWidget);
  });

  testWidgets('GivenATransportFailure_WhenOpened_ThenARetryIsOffered', (
    tester,
  ) async {
    // Given
    answerWith(
      const FailureResult<envelope.Page<Application>>(
        Failure(kind: FailureKind.network, errors: <String>[]),
      ),
    );

    // When
    await pump(tester);

    // Then
    expect(find.widgetWithText(TextButton, 'Retry'), findsOneWidget);
  });

  // AF-20c — a scope this admin does not own.
  testWidgets('GivenAForbiddenScope_WhenOpened_ThenTheRolePanelIsShown', (
    tester,
  ) async {
    // Given
    answerWith(
      const FailureResult<envelope.Page<Application>>(
        Failure(kind: FailureKind.forbidden, errors: <String>[]),
      ),
    );

    // When
    await pump(tester);

    // Then
    expect(find.text('Not available for your role'), findsOneWidget);
  });

  testWidgets('GivenIncludeDeleted_WhenToggled_ThenTheFlagIsSent', (
    tester,
  ) async {
    // Given
    answerWith(Success<envelope.Page<Application>>(_page()));
    await pump(tester);

    // When
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    // Then
    verify(
      () => applications.list(
        scopeId: 'scope-1',
        name: '',
        includeDeleted: true,
        pageNumber: 1,
      ),
    ).called(1);
  });

  testWidgets('GivenTheCreateControl_WhenTapped_ThenTheFormOpens', (
    tester,
  ) async {
    // Given
    answerWith(Success<envelope.Page<Application>>(_page()));
    await pump(tester);

    // When
    await tester.tap(
      find.widgetWithText(FloatingActionButton, 'New application'),
    );
    await tester.pumpAndSettle();

    // Then
    expect(find.text('create'), findsOneWidget);
  });

  testWidgets('GivenTheDarkTheme_WhenListed_ThenTheApplicationsAreStillShown', (
    tester,
  ) async {
    // Given
    answerWith(Success<envelope.Page<Application>>(_page()));

    // When
    await pump(tester, theme: buildDarkTheme());

    // Then
    expect(find.text('Billing'), findsOneWidget);
  });
}
