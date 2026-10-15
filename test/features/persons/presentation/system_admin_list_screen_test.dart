import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:heimdall_ui/app/theme.dart';
import 'package:heimdall_ui/core/network/envelope.dart' as envelope;
import 'package:heimdall_ui/core/result/result.dart';
import 'package:heimdall_ui/core/storage/token_store.dart';
import 'package:heimdall_ui/features/auth/presentation/session_controller.dart';
import 'package:heimdall_ui/features/persons/domain/person.dart';
import 'package:heimdall_ui/features/persons/domain/person_repository.dart';
import 'package:heimdall_ui/features/persons/presentation/system_admin_list_screen.dart';
import 'package:heimdall_ui/features/profile/presentation/profile_controller.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockPersonRepository extends Mock implements PersonRepository {}

String _jwt() {
  final payload = base64Url.encode(
    utf8.encode(
      jsonEncode(<String, dynamic>{
        'sub': 'admin-9',
        'email': 'admin@example.com',
        'role': 1,
      }),
    ),
  );

  return 'header.$payload.signature';
}

const _ada = PersonSummary(
  id: 'admin-1',
  name: 'Ada',
  email: 'ada@example.com',
);

envelope.Page<PersonSummary> _page({
  List<PersonSummary> items = const <PersonSummary>[_ada],
  int pageNumber = 1,
  int totalPages = 1,
}) => envelope.Page<PersonSummary>(
  items: items,
  pageNumber: pageNumber,
  pageSize: 20,
  totalItems: items.length,
  totalPages: totalPages,
);

const Size _expanded = Size(1400, 900);

void main() {
  late _MockPersonRepository repository;
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
        personRepositoryProvider.overrideWithValue(repository),
        tokenStoreProvider.overrideWithValue(store),
      ],
    );
    addTearDown(container.dispose);
    await container.read(sessionControllerProvider.notifier).restore();

    router = GoRouter(
      initialLocation: '/system-admins',
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(body: Text('home')),
        ),
        GoRoute(
          path: '/system-admins',
          builder: (context, state) => const SystemAdminListScreen(),
        ),
        GoRoute(
          path: '/persons/:personId',
          builder: (context, state) => Scaffold(
            body: Text('person ${state.pathParameters['personId']}'),
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

  void answerWith(Result<envelope.Page<PersonSummary>> result) {
    when(
      () => repository.listSystemAdmins(
        name: any(named: 'name'),
        email: any(named: 'email'),
        pageNumber: any(named: 'pageNumber'),
        pageSize: any(named: 'pageSize'),
      ),
    ).thenAnswer((_) async => result);
  }

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    repository = _MockPersonRepository();
    store = InMemoryTokenStore();
  });

  testWidgets('GivenAdmins_WhenOpenedWide_ThenATableShowsNameAndEmail', (
    tester,
  ) async {
    // Given
    answerWith(Success<envelope.Page<PersonSummary>>(_page()));

    // When
    await pump(tester);

    // Then
    expect(find.text('System Admins'), findsWidgets);
    expect(find.text('Ada'), findsOneWidget);
    expect(find.text('ada@example.com'), findsOneWidget);
    expect(
      find.text(
        'System Admins can administer every scope. Deleted and '
        'restricted accounts are not listed.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('GivenTheSignedInAdmin_WhenListed_ThenTheirRowIsMarked', (
    tester,
  ) async {
    // Given
    answerWith(
      Success<envelope.Page<PersonSummary>>(
        _page(
          items: const <PersonSummary>[
            PersonSummary(id: 'admin-9', name: 'Me', email: 'me@example.com'),
          ],
        ),
      ),
    );

    // When
    await pump(tester);

    // Then
    expect(find.text('Me (you)'), findsOneWidget);
  });

  testWidgets('GivenAdmins_WhenARowIsTapped_ThenTheirPageOpens', (
    tester,
  ) async {
    // Given
    answerWith(Success<envelope.Page<PersonSummary>>(_page()));
    await pump(tester);

    // When
    await tester.tap(find.text('Ada'));
    await tester.pumpAndSettle();

    // Then
    expect(find.text('person admin-1'), findsOneWidget);
  });

  testWidgets('GivenANameTyped_WhenSearchIsPressed_ThenItIsSent', (
    tester,
  ) async {
    // Given
    answerWith(Success<envelope.Page<PersonSummary>>(_page()));
    await pump(tester);

    // When
    await tester.enterText(
      find.widgetWithText(TextField, 'Search by name'),
      'Ada',
    );
    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();

    // Then
    verify(
      () => repository.listSystemAdmins(
        name: 'Ada',
        email: '',
        pageNumber: 1,
        pageSize: any(named: 'pageSize'),
      ),
    ).called(1);
  });

  testWidgets('GivenAFilterWithNoMatches_WhenShown_ThenClearFiltersIsOffered', (
    tester,
  ) async {
    // Given
    answerWith(
      Success<envelope.Page<PersonSummary>>(
        _page(items: const <PersonSummary>[]),
      ),
    );
    await pump(tester);
    await tester.enterText(
      find.widgetWithText(TextField, 'Search by name'),
      'Zed',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    // Then
    expect(find.text('No System Admins match.'), findsOneWidget);
    expect(find.text('Clear filters'), findsOneWidget);
  });

  testWidgets('GivenNobodyAndNoFilter_WhenShown_ThenTheEmptyStateShows', (
    tester,
  ) async {
    // Given
    answerWith(
      Success<envelope.Page<PersonSummary>>(
        _page(items: const <PersonSummary>[]),
      ),
    );

    // When
    await pump(tester);

    // Then
    expect(find.text('No System Admins.'), findsOneWidget);
    expect(find.text('Clear filters'), findsNothing);
  });

  testWidgets('GivenA403_WhenOpened_ThenTheForbiddenStateShows', (
    tester,
  ) async {
    // Given
    answerWith(
      const FailureResult<envelope.Page<PersonSummary>>(
        Failure(kind: FailureKind.forbidden, errors: <String>['No.']),
      ),
    );

    // When
    await pump(tester);

    // Then
    expect(find.text('Not available for your role'), findsOneWidget);
    expect(find.text('Back to Home'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('GivenAServerFailure_WhenOpened_ThenRetryIsOffered', (
    tester,
  ) async {
    // Given
    answerWith(
      const FailureResult<envelope.Page<PersonSummary>>(
        Failure(kind: FailureKind.server, errors: <String>['Boom.']),
      ),
    );

    // When
    await pump(tester);

    // Then
    expect(find.text('Boom.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  for (final size in <Size>[const Size(360, 640), _expanded]) {
    testWidgets(
      'GivenALongName_WhenShownAt${size.width.toInt()}_ThenNothingOverflows',
      (tester) async {
        // Given
        answerWith(
          Success<envelope.Page<PersonSummary>>(
            _page(
              items: <PersonSummary>[
                PersonSummary(
                  id: 'admin-1',
                  name: 'A' * 200,
                  email: 'ada@example.com',
                ),
              ],
            ),
          ),
        );

        // When
        await pump(tester, size: size);

        // Then
        expect(tester.takeException(), isNull);
      },
    );
  }
}
