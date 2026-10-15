# UI-38: List System Admins — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A System Admin opens a searchable, paged list of the system's System Admins from a Home tile, and opens each one's person page without needing a scope.

**Architecture:**
- A `listSystemAdmins` repository method over the generated `personListSystemAdmins` client call.
- An `autoDispose` list controller and screen at `/system-admins`, modelled on UI-16's person list.
- `PersonDetailScreen` with an optional `scopeId`, served at `/persons/:personId`.
- A count tile on the dashboard.

**Tech Stack:** Flutter 3.47.7 / Dart 3.13.5, Riverpod 3 (`Notifier`), go_router 18, mocktail, the generated `heimdall_api_client`.

**Spec:** `docs/superpowers/specs/2026-10-15-system-admins-list-design.md`

## Global Constraints

- **Toolchain.** Prefix every flutter or dart command with `export PATH=/root/develop/flutter-3.47.7/flutter/bin:/root/develop/flutter-3.47.7/flutter/bin/cache/dart-sdk/bin:$PATH`.
- **Gate.** Run `dart format --set-exit-if-changed . && flutter analyze && flutter test -j 2` before each commit.
- **Tests.**
  - Test names follow `GivenCondition_WhenAction_ThenOutcome`, with `// Given`, `// When` and `// Then` sections.
  - TDD: see each new test fail first.
- **Commits.**
  - The subject is a lowercase Conventional Commit of 50 characters or fewer; wrap the body at 72.
  - Stage files explicitly.
  - Every message ends with exactly:
    ```
    Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
    Claude-Session: https://claude.ai/code/session_01KU2awQWyVHDRk4zc4mKYjv
    ```
- **Copy, verbatim from the spec.**
  - Screen title: "System Admins".
  - Back tooltip on the list: "Back to Home".
  - The line above the list: "System Admins can administer every scope. Deleted and restricted accounts are not listed."
  - No matches: "No System Admins match." with the action "Clear filters".
  - Empty: "No System Admins."
  - Own-row marker: " (you)", appended to the name.
  - Home tile: label "System Admins", caption "Full access to every scope".
  - Person page back tooltip when there is no scope: "Back to System Admins".
- **API.** `GET /api/persons/system-admins` returns only `id`, `name` and `email`. It is System Admin only, and returns neither deleted nor restricted persons.
- **No new navigation destination** (#144 depends on that).

## Decisions (amendments to the spec, recorded in Task 6)

1. **Overlapping loads queue the newest query.** The spec says loads are refused. Instead, a load requested while one is in flight is queued, and every change builds from `_queued ?? state.query`. This is UI-16's pattern, plus Part A's fix: refusing would drop a search typed during a load.
2. **No explicit list refresh after an edit or a delete.** The list provider is `autoDispose`, and navigating to `/persons/:id` disposes it, so the list re-reads when the admin returns. A delete on a scope-less page goes to `/system-admins`, which loads fresh.
3. **Filters use a Search button and Enter,** exactly as UI-16 does, not a suffix search icon.

## Review Focus

1. **Searching during a slow load:** the newest search must win and nothing may be lost. Task 2 tests a queued search.
2. **A System Admin opening their own record from the list:** the page keeps its self-protections, with no delete and no account emails. Task 4 tests it.
3. **A deep link to `/persons/:id` or `/system-admins` as a Scope Admin:** they see the not-available screen. Task 3 and Task 4 test the route rules.
4. **The dashboard count failing:** the tile shows "—" and still opens the list, and the other tiles are unaffected. Task 5 tests it.
5. **A long name or email in the table:** `AdaptiveCollection` bounds the title cell, so no overflow at 1400 px or 360 px. Task 3 tests it with a 200-character name.

---

### Task 1: Read the System Admins listing

**Files:**
- Modify: `lib/features/persons/domain/person_repository.dart` (after `listScopeAdmins`, ~line 87)
- Modify: `lib/features/persons/data/person_repository_impl.dart` (after `listScopeAdmins`, ~line 303)
- Test: `test/features/persons/data/person_repository_impl_test.dart`

**Interfaces:**
- Produces: `Future<Result<Page<PersonSummary>>> listSystemAdmins({String? name, String? email, int pageNumber = 1, int pageSize = 20})` on `PersonRepository`, implemented by `ApiPersonRepository`.

- [ ] **Step 1: Write the failing tests** (append inside `main()`, using the file's `repositoryAnswering` and `adapter`):

```dart
  test('GivenSystemAdmins_WhenListed_ThenTheyAreReturned', () async {
    // Given
    final repository = repositoryAnswering(
      const _Answer(
        status: 200,
        body: <String, dynamic>{
          'success': true,
          'errors': <String>[],
          'data': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'admin-1',
              'name': 'Ada',
              'email': 'ada@example.com',
            },
          ],
          'pageNumber': 2,
          'pageSize': 20,
          'totalItems': 21,
          'totalPages': 2,
        },
      ),
    );

    // When
    final result = await repository.listSystemAdmins(pageNumber: 2);

    // Then
    final page = result.valueOrNull!;
    expect(page.items.single.id, 'admin-1');
    expect(page.items.single.name, 'Ada');
    expect(page.totalItems, 21);
    expect(adapter.paths.single, '/api/persons/system-admins');
    expect(adapter.queries.single['PageNumber'], '2');
    expect(adapter.queries.single['PageSize'], '20');
  });

  test('GivenFilters_WhenSystemAdminsListed_ThenTheyAreSent', () async {
    // Given
    final repository = repositoryAnswering(
      const _Answer(
        status: 200,
        body: <String, dynamic>{
          'success': true,
          'errors': <String>[],
          'data': <Map<String, dynamic>>[],
        },
      ),
    );

    // When
    await repository.listSystemAdmins(name: 'Ada', email: '  ');

    // Then
    expect(adapter.queries.single['Name'], 'Ada');
    expect(adapter.queries.single.containsKey('Email'), isFalse);
  });

  test('GivenA403_WhenSystemAdminsListed_ThenForbiddenIsReturned', () async {
    // Given
    final repository = repositoryAnswering(
      const _Answer(
        status: 403,
        body: <String, dynamic>{
          'success': false,
          'errors': <String>['Only a System Admin may list System Admins.'],
        },
      ),
    );

    // When
    final result = await repository.listSystemAdmins();

    // Then
    expect(result.failureOrNull?.kind, FailureKind.forbidden);
  });
```

- [ ] **Step 2: Run them to see them fail.**
  - Run: `flutter test test/features/persons/data/person_repository_impl_test.dart`
  - Expected: a compile error, "The method 'listSystemAdmins' isn't defined".
- [ ] **Step 3: Add the interface method.** In `person_repository.dart`, after `listScopeAdmins`:

```dart
  /// UC-07 read (e) — the system's System Admins, projected to identifier,
  /// name, and email. The API answers it to a System Admin only, leaves out
  /// deleted and restricted accounts, and orders by name.
  Future<Result<Page<PersonSummary>>> listSystemAdmins({
    String? name,
    String? email,
    int pageNumber = 1,
    int pageSize = 20,
  });
```

- [ ] **Step 4: Implement it.** In `person_repository_impl.dart`, after `listScopeAdmins`:

```dart
  @override
  Future<Result<Page<PersonSummary>>> listSystemAdmins({
    String? name,
    String? email,
    int pageNumber = 1,
    int pageSize = 20,
  }) async {
    try {
      final response = await _client.personListSystemAdmins(
        name: _filter(name),
        email: _filter(email),
        pageNumber: pageNumber,
        pageSize: pageSize,
      );

      if (response.success != true) {
        return FailureResult<Page<PersonSummary>>(
          Failure(
            kind: FailureKind.validation,
            errors: response.errors ?? const <String>[],
          ),
        );
      }

      final items = (response.data ?? const <PersonSummaryOutput>[])
          .map(
            (output) => PersonSummary(
              id: output.id ?? '',
              name: output.name ?? '',
              email: output.email ?? '',
            ),
          )
          .toList(growable: false);

      return Success<Page<PersonSummary>>(
        Page<PersonSummary>(
          items: items,
          pageNumber: response.pageNumber ?? pageNumber,
          pageSize: response.pageSize ?? pageSize,
          totalItems: response.totalItems ?? items.length,
          totalPages: response.totalPages ?? 1,
        ),
      );
    } on DioException catch (error) {
      return FailureResult<Page<PersonSummary>>(failureFromDioException(error));
    }
  }
```

  If the generated method's parameter names differ, use theirs; check `packages/heimdall_api_client/lib/clients/person_client.dart`.
- [ ] **Step 5: Run the tests and the gate.**
  - Run: `flutter test test/features/persons/data/person_repository_impl_test.dart`, then the gate.
  - Expected: PASS. Every `implements PersonRepository` under `test/` extends `Mock` or `Fake`, so none needs the new method yet. Task 5 adds it to the dashboard fake.
- [ ] **Step 6: Commit.**

```bash
git add lib/features/persons/domain/person_repository.dart lib/features/persons/data/person_repository_impl.dart test/features/persons/data/person_repository_impl_test.dart
git commit   # subject: feat(ui-38): read the system admins listing
```

---

### Task 2: The list controller

**Files:**
- Create: `lib/features/persons/presentation/system_admin_list_controller.dart`
- Test: `test/features/persons/presentation/system_admin_list_controller_test.dart`

**Interfaces:**
- Consumes: Task 1's `listSystemAdmins`; `personRepositoryProvider` (from `../../profile/presentation/profile_controller.dart`).
- Produces:
  - `class SystemAdminQuery { String name; String email; int pageNumber; bool get isFiltered; SystemAdminQuery copyWith(...) }`
  - `sealed class SystemAdminListState { SystemAdminQuery query; }`, with these subtypes:
    - `SystemAdminListLoading`;
    - `SystemAdminListLoaded(query, Page<PersonSummary> page, {bool busy})`;
    - `SystemAdminListFailed(query, Failure failure)`, with `isForbidden`.
  - `systemAdminListControllerProvider`, a `NotifierProvider.autoDispose<SystemAdminListController, SystemAdminListState>`.
  - Methods: `load()`, `search({String? name, String? email})`, `goToPage(int)`, `clearFilters()`.

- [ ] **Step 1: Write the failing tests.**

```dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/core/network/envelope.dart';
import 'package:heimdall_ui/core/result/result.dart';
import 'package:heimdall_ui/features/persons/domain/person.dart';
import 'package:heimdall_ui/features/persons/domain/person_repository.dart';
import 'package:heimdall_ui/features/persons/presentation/system_admin_list_controller.dart';
import 'package:heimdall_ui/features/profile/presentation/profile_controller.dart';
import 'package:mocktail/mocktail.dart';

class _MockPersonRepository extends Mock implements PersonRepository {}

const _ada = PersonSummary(id: 'admin-1', name: 'Ada', email: 'ada@example.com');

Page<PersonSummary> _page({
  List<PersonSummary> items = const <PersonSummary>[_ada],
  int pageNumber = 1,
  int totalPages = 1,
}) => Page<PersonSummary>(
  items: items,
  pageNumber: pageNumber,
  pageSize: 20,
  totalItems: items.length,
  totalPages: totalPages,
);

void main() {
  late _MockPersonRepository repository;
  late ProviderContainer container;
  late ProviderSubscription<SystemAdminListState> subscription;

  SystemAdminListController controllerUnderTest() {
    container = ProviderContainer(
      overrides: <Override>[
        personRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    // An autoDispose provider needs a listener to stay alive between reads.
    subscription = container.listen(
      systemAdminListControllerProvider,
      (_, _) {},
    );

    return container.read(systemAdminListControllerProvider.notifier);
  }

  SystemAdminListState currentState() =>
      container.read(systemAdminListControllerProvider);

  void answerWith(Future<Result<Page<PersonSummary>>> Function() answer) {
    when(
      () => repository.listSystemAdmins(
        name: any(named: 'name'),
        email: any(named: 'email'),
        pageNumber: any(named: 'pageNumber'),
        pageSize: any(named: 'pageSize'),
      ),
    ).thenAnswer((_) => answer());
  }

  setUp(() {
    repository = _MockPersonRepository();
  });

  test('GivenAPage_WhenLoaded_ThenTheAdminsAreShown', () async {
    // Given
    answerWith(() async => Success<Page<PersonSummary>>(_page()));
    final controller = controllerUnderTest();

    // When
    await controller.load();

    // Then
    expect(
      (currentState() as SystemAdminListLoaded).page.items.single.name,
      'Ada',
    );
  });

  test('GivenPageTwo_WhenSearched_ThenTheFirstPageIsAsked', () async {
    // Given
    answerWith(
      () async => Success<Page<PersonSummary>>(_page(pageNumber: 2, totalPages: 2)),
    );
    final controller = controllerUnderTest();
    await controller.goToPage(2);

    // When
    await controller.search(name: 'Ada');

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

  test('GivenALoadInFlight_WhenTwoSearchesArrive_ThenBothFiltersReachTheLastRequest', () async {
    // Given
    final first = Completer<Result<Page<PersonSummary>>>();
    var calls = 0;
    answerWith(() {
      calls++;

      return calls == 1
          ? first.future
          : Future.value(Success<Page<PersonSummary>>(_page()));
    });
    final controller = controllerUnderTest();
    final loading = controller.load();

    // When
    unawaited(controller.search(name: 'Ada'));
    unawaited(controller.search(email: 'ada@example.com'));
    first.complete(Success<Page<PersonSummary>>(_page()));
    await loading;
    await pumpEventQueue();

    // Then
    verify(
      () => repository.listSystemAdmins(
        name: 'Ada',
        email: 'ada@example.com',
        pageNumber: 1,
        pageSize: any(named: 'pageSize'),
      ),
    ).called(1);
    expect(calls, 2);
  });

  test('GivenA403_WhenLoaded_ThenTheStateIsForbidden', () async {
    // Given
    answerWith(
      () async => const FailureResult<Page<PersonSummary>>(
        Failure(kind: FailureKind.forbidden, errors: <String>['No.']),
      ),
    );
    final controller = controllerUnderTest();

    // When
    await controller.load();

    // Then
    expect((currentState() as SystemAdminListFailed).isForbidden, isTrue);
  });

  test('GivenFilters_WhenTheScreenIsLeft_ThenTheListStartsFresh', () async {
    // Given
    answerWith(() async => Success<Page<PersonSummary>>(_page()));
    final controller = controllerUnderTest();
    await controller.search(name: 'Ada');

    // When
    subscription.close();
    await pumpEventQueue();

    // Then
    expect(currentState().query.name, '');
  });
}
```

- [ ] **Step 2: Run them to see them fail.**
  - Run: `flutter test test/features/persons/presentation/system_admin_list_controller_test.dart`
  - Expected: compile error, because the URI doesn't exist.
- [ ] **Step 3: Write the controller.**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/envelope.dart';
import '../../../core/result/result.dart';
import '../../profile/presentation/profile_controller.dart';
import '../domain/person.dart';

/// What the System Admins listing is asking the API for (UI-38).
class SystemAdminQuery {
  const SystemAdminQuery({this.name = '', this.email = '', this.pageNumber = 1});

  final String name;
  final String email;
  final int pageNumber;

  /// Whether the admin has narrowed the listing, which tells "no matches"
  /// from "nobody" (AF-38a/b).
  bool get isFiltered => name.trim().isNotEmpty || email.trim().isNotEmpty;

  SystemAdminQuery copyWith({String? name, String? email, int? pageNumber}) =>
      SystemAdminQuery(
        name: name ?? this.name,
        email: email ?? this.email,
        pageNumber: pageNumber ?? this.pageNumber,
      );
}

/// How far the listing has got. The query travels with every state, so the
/// filters survive a failure and a retry.
sealed class SystemAdminListState {
  const SystemAdminListState(this.query);

  final SystemAdminQuery query;
}

final class SystemAdminListLoading extends SystemAdminListState {
  const SystemAdminListLoading(super.query);
}

/// A page arrived. [busy] keeps the rows on screen while a further page or
/// search is in flight.
final class SystemAdminListLoaded extends SystemAdminListState {
  const SystemAdminListLoaded(super.query, this.page, {this.busy = false});

  final Page<PersonSummary> page;
  final bool busy;
}

/// AF-38c/d — the request failed, and the query that failed is kept.
final class SystemAdminListFailed extends SystemAdminListState {
  const SystemAdminListFailed(super.query, this.failure);

  final Failure failure;

  /// AF-38c — only a System Admin may list System Admins.
  bool get isForbidden => failure.kind == FailureKind.forbidden;
}

/// Disposed when the screen is left, so a return starts from a fresh,
/// unfiltered list rather than a stale one.
final AutoDisposeNotifierProvider<SystemAdminListController, SystemAdminListState>
systemAdminListControllerProvider =
    NotifierProvider.autoDispose<SystemAdminListController, SystemAdminListState>(
      SystemAdminListController.new,
    );

/// Owns the System Admins listing: its filters, its page, and the request in
/// flight.
class SystemAdminListController extends Notifier<SystemAdminListState> {
  bool _inFlight = false;

  /// The newest query asked for while another was in flight, asked as soon as
  /// that one is answered.
  SystemAdminQuery? _queued;

  /// What the next change builds on: the queued query when there is one, so
  /// two changes during one load both survive.
  SystemAdminQuery get _latest => _queued ?? state.query;

  @override
  SystemAdminListState build() =>
      const SystemAdminListLoading(SystemAdminQuery());

  Future<void> load() => _fetch(_latest);

  /// A new search starts at the first page.
  Future<void> search({String? name, String? email}) =>
      _fetch(_latest.copyWith(name: name, email: email, pageNumber: 1));

  Future<void> goToPage(int pageNumber) =>
      _fetch(_latest.copyWith(pageNumber: pageNumber));

  Future<void> clearFilters() => _fetch(const SystemAdminQuery());

  Future<void> _fetch(SystemAdminQuery query) async {
    if (_inFlight) {
      _queued = query;

      return;
    }

    final current = state;
    _inFlight = true;

    state = current is SystemAdminListLoaded
        ? SystemAdminListLoaded(query, current.page, busy: true)
        : SystemAdminListLoading(query);

    final Result<Page<PersonSummary>> result;

    try {
      result = await ref
          .read(personRepositoryProvider)
          .listSystemAdmins(
            name: query.name,
            email: query.email,
            pageNumber: query.pageNumber,
          );
    } finally {
      _inFlight = false;
    }

    if (!ref.mounted) {
      return;
    }

    state = result.fold(
      onSuccess: (page) => SystemAdminListLoaded(query, page),
      onFailure: (failure) => SystemAdminListFailed(query, failure),
    );

    if (_queued case final queued?) {
      _queued = null;
      await _fetch(queued);
    }
  }
}
```

  If `AutoDisposeNotifierProvider` isn't exported under that name in this Riverpod version, follow the type annotation used by `restrict_processing_controller.dart`'s `NotifierProvider.autoDispose`.
- [ ] **Step 4: Run the tests, then the gate.** Expected: PASS.
- [ ] **Step 5: Commit.**

```bash
git add lib/features/persons/presentation/system_admin_list_controller.dart test/features/persons/presentation/system_admin_list_controller_test.dart
git commit   # subject: feat(ui-38): page and search system admins
```

---

### Task 3: The list screen and its route

**Files:**
- Create: `lib/features/persons/presentation/system_admin_list_screen.dart`
- Modify: `lib/app/router.dart` (add the route after `/scopes/:scopeId/persons/:personId`, ~line 266)
- Modify: `lib/app/route_access.dart` (add a rule before `_ => true`)
- Test: `test/features/persons/presentation/system_admin_list_screen_test.dart`, `test/app/route_access_test.dart`

**Interfaces:**
- Consumes: Task 2's provider and states.
- Produces: `class SystemAdminListScreen extends ConsumerStatefulWidget` (no parameters); route `/system-admins`; `roleMayReach` rule `'/system-admins' => role == Role.systemAdmin`.

- [ ] **Step 1: Write the failing route-access test** (append to `route_access_test.dart`):

```dart
  test('GivenASystemAdmin_WhenSystemAdminsAsked_ThenTheyAreReachable', () {
    expect(roleMayReach(role: Role.systemAdmin, path: '/system-admins'), isTrue);
  });

  for (final role in <Role>[Role.scopeAdmin, Role.user]) {
    test('Given${role.name}_WhenSystemAdminsAsked_ThenTheyAreNot', () {
      expect(roleMayReach(role: role, path: '/system-admins'), isFalse);
    });
  }
```

- [ ] **Step 2: Write the failing screen tests.**
  - Copy `person_list_screen_test.dart`'s harness: the token store, a session from `_jwt`, `ProviderContainer`, a `GoRouter`, and `UncontrolledProviderScope` with `MaterialApp.router` and the app theme.
  - Changes to the harness:
    - the JWT has `'sub': 'admin-9'` and `'role': 0` (System Admin);
    - `initialLocation: '/system-admins'`;
    - routes are `/` (a `Text('home')` scaffold), `/system-admins` (the screen) and `/persons/:personId` (a `Text('person ${id}')` scaffold);
    - the mock answers `listSystemAdmins`.

  The tests:

```dart
  testWidgets('GivenAdmins_WhenOpenedWide_ThenATableShowsNameAndEmail', (tester) async {
    // Given
    answerWith(Success<envelope.Page<PersonSummary>>(_page()));

    // When
    await pump(tester);

    // Then
    expect(find.text('System Admins'), findsWidgets);
    expect(find.text('Ada'), findsOneWidget);
    expect(find.text('ada@example.com'), findsOneWidget);
    expect(
      find.text('System Admins can administer every scope. Deleted and '
          'restricted accounts are not listed.'),
      findsOneWidget,
    );
  });

  testWidgets('GivenTheSignedInAdmin_WhenListed_ThenTheirRowIsMarked', (tester) async {
    // Given — admin-9 is the signed-in principal
    answerWith(Success<envelope.Page<PersonSummary>>(_page(items: const <PersonSummary>[
      PersonSummary(id: 'admin-9', name: 'Me', email: 'me@example.com'),
    ])));

    // When
    await pump(tester);

    // Then
    expect(find.text('Me (you)'), findsOneWidget);
  });

  testWidgets('GivenAdmins_WhenARowIsTapped_ThenTheirPageOpens', (tester) async {
    // Given
    answerWith(Success<envelope.Page<PersonSummary>>(_page()));
    await pump(tester);

    // When
    await tester.tap(find.text('Ada'));
    await tester.pumpAndSettle();

    // Then
    expect(find.text('person admin-1'), findsOneWidget);
  });

  testWidgets('GivenANameTyped_WhenSearchIsPressed_ThenItIsSent', (tester) async {
    // Given
    answerWith(Success<envelope.Page<PersonSummary>>(_page()));
    await pump(tester);

    // When
    await tester.enterText(find.widgetWithText(TextField, 'Search by name'), 'Ada');
    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();

    // Then
    verify(() => repository.listSystemAdmins(
      name: 'Ada',
      email: '',
      pageNumber: 1,
      pageSize: any(named: 'pageSize'),
    )).called(1);
  });

  testWidgets('GivenAFilterWithNoMatches_WhenShown_ThenClearFiltersIsOffered', (tester) async {
    // Given
    answerWith(Success<envelope.Page<PersonSummary>>(_page(items: const <PersonSummary>[])));
    await pump(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Search by name'), 'Zed');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    // Then
    expect(find.text('No System Admins match.'), findsOneWidget);
    expect(find.text('Clear filters'), findsOneWidget);
  });

  testWidgets('GivenA403_WhenOpened_ThenTheForbiddenStateShows', (tester) async {
    // Given
    answerWith(const FailureResult<envelope.Page<PersonSummary>>(
      Failure(kind: FailureKind.forbidden, errors: <String>['No.']),
    ));

    // When
    await pump(tester);

    // Then
    expect(find.text('Not available for your role'), findsOneWidget);
    expect(find.text('Back to Home'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('GivenAServerFailure_WhenOpened_ThenRetryIsOffered', (tester) async {
    // Given
    answerWith(const FailureResult<envelope.Page<PersonSummary>>(
      Failure(kind: FailureKind.server, errors: <String>['Boom.']),
    ));

    // When
    await pump(tester);

    // Then
    expect(find.text('Boom.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('GivenALongName_WhenShownAt360_ThenNothingOverflows', (tester) async {
    // Given
    answerWith(Success<envelope.Page<PersonSummary>>(_page(items: <PersonSummary>[
      PersonSummary(id: 'admin-1', name: 'A' * 200, email: 'ada@example.com'),
    ])));

    // When
    await pump(tester, size: const Size(360, 640));

    // Then
    expect(tester.takeException(), isNull);
  });
```

- [ ] **Step 3: Run them to see them fail.**
  - Run: `flutter test test/app/route_access_test.dart test/features/persons/presentation/system_admin_list_screen_test.dart`
  - Expected: FAIL. The route rule answers true for the Scope Admin and the User, and the screen file doesn't exist.
- [ ] **Step 4: Add the route rule.** In `route_access.dart`, before the final `_ => true`:

```dart
  // UC-07 read (e) is answered to a System Admin only: who else holds full
  // access is not a Scope Admin's to know.
  '/system-admins' => role == Role.systemAdmin,
```

- [ ] **Step 5: Write the screen.**
  - It follows `person_list_screen.dart`'s structure and the `_Filters` widget, without the include-deleted switch and without a FAB.
  - Use `AppShell(currentRoute: '/', title: const Text('System Admins'), backRoute: '/', backTooltip: 'Back to Home', body: …)`.
  - The body is a `Column`:
    1. the filters (`Search by name`, `Search by email`, a `Search` tonal button; Enter submits);
    2. the explanatory line in `bodySmall` with `onSurfaceVariant`, padded `EdgeInsets.fromLTRB(16, 8, 16, 0)`;
    3. `Expanded(child: switch (state) …)`.
  - The switch arms:

```dart
              SystemAdminListLoading() => const CollectionLoading(),
              SystemAdminListFailed(isForbidden: true) => CollectionEmpty(
                title: 'Not available for your role',
                message: 'Only a System Admin may see who the System Admins '
                    'are. Nothing is wrong with your session.',
                icon: Icons.lock_person_outlined,
                actionLabel: 'Back to Home',
                onAction: () => context.go('/'),
              ),
              SystemAdminListFailed(:final failure) => CollectionFailed(
                failure: failure,
                onRetry: _controller.load,
              ),
              SystemAdminListLoaded(:final page, :final query)
                  when page.items.isEmpty => query.isFiltered
                  ? CollectionEmpty(
                      title: 'No System Admins match.',
                      message: 'Nothing here matches what you searched for.',
                      icon: Icons.search_off_outlined,
                      actionLabel: 'Clear filters',
                      onAction: _clearFilters,
                    )
                  : const CollectionEmpty(
                      title: 'No System Admins.',
                      message: 'There are no System Admins to show.',
                      icon: Icons.admin_panel_settings_outlined,
                    ),
              final SystemAdminListLoaded loaded => AdaptiveCollection<PersonSummary>(
                items: loaded.page.items,
                busy: loaded.busy,
                pageNumber: loaded.page.pageNumber,
                totalPages: loaded.page.totalPages,
                totalItems: loaded.page.totalItems,
                onPageChanged: _controller.goToPage,
                onTap: (admin) => context.go('/persons/${admin.id}'),
                title: (admin) => admin.id == _me ? '${admin.name} (you)' : admin.name,
                subtitle: (admin) => admin.email,
                columns: const <CollectionColumn<PersonSummary>>[],
              ),
```

  - `_me` comes from `ref.watch(sessionControllerProvider)`: `session is Authenticated ? session.principal.id : null`.
  - `initState` loads after the first frame, as `PersonListScreen` does. There are no remembered filters to restore, since the provider is autoDispose.
  - If `AdaptiveCollection` requires a non-empty `columns`, check its constructor. If it does, the table's subtitle cell already shows the email, so add no column.
- [ ] **Step 6: Add the route.** In `router.dart`, after `/scopes/:scopeId/persons/:personId`:

```dart
      GoRoute(
        path: '/system-admins',
        builder: (context, state) => const SystemAdminListScreen(),
      ),
```

  Import the screen.
- [ ] **Step 7: Run the tests, then the gate.** Expected: PASS.
- [ ] **Step 8: Commit.**

```bash
git add lib/features/persons/presentation/system_admin_list_screen.dart lib/app/router.dart lib/app/route_access.dart test/features/persons/presentation/system_admin_list_screen_test.dart test/app/route_access_test.dart
git commit   # subject: feat(ui-38): list the system admins
```

---

### Task 4: A person page without a scope

**Files:**
- Modify: `lib/features/persons/presentation/person_detail_screen.dart:22-30, 217-236`
- Modify: `lib/app/router.dart` (add `/persons/:personId`)
- Modify: `lib/app/route_access.dart`
- Test: `test/features/persons/presentation/person_detail_screen_test.dart`, `test/app/route_access_test.dart`

**Interfaces:**
- Consumes: the route `/system-admins` from Task 3.
- Produces:
  - `PersonDetailScreen({String? scopeId, required String personId})`;
  - the route `/persons/:personId`;
  - the `roleMayReach` rule `'/persons/…'` for System Admins only.

- [ ] **Step 1: Write the failing route-access tests:**

```dart
  test('GivenASystemAdmin_WhenAPersonPageAsked_ThenItIsReachable', () {
    expect(roleMayReach(role: Role.systemAdmin, path: '/persons/p1'), isTrue);
  });

  for (final role in <Role>[Role.scopeAdmin, Role.user]) {
    test('Given${role.name}_WhenAPersonPageAsked_ThenItIsNot', () {
      expect(roleMayReach(role: role, path: '/persons/p1'), isFalse);
    });
  }
```

- [ ] **Step 2: Write the failing screen tests.** In `person_detail_screen_test.dart`:
  - Give the harness's `pump` an optional `String initialLocation = '/scopes/scope-1/persons/person-1'`.
  - Add these routes: `/persons/:personId`, building `PersonDetailScreen(personId: …)` with no scope, and `/system-admins`, building `Scaffold(body: Text('system admins'))`.

```dart
  testWidgets('GivenNoScope_WhenOpened_ThenBackGoesToSystemAdmins', (tester) async {
    // Given — a System Admin (role 0) opens another System Admin
    when(() => repository.getById('person-1', includeDeleted: true))
        .thenAnswer((_) async => const Success<Person>(Person(
              id: 'person-1',
              name: 'Grace',
              email: 'grace@example.com',
              role: Role.systemAdmin,
            )));
    await pump(tester, role: 0, initialLocation: '/persons/person-1');

    // When
    await tester.tap(find.byTooltip('Back to System Admins'));
    await tester.pumpAndSettle();

    // Then
    expect(find.text('system admins'), findsOneWidget);
  });

  testWidgets('GivenNoScope_WhenOwnRecordOpened_ThenItStaysProtected', (tester) async {
    // Given — the signed-in System Admin opens themselves
    when(() => repository.getById('person-9', includeDeleted: true))
        .thenAnswer((_) async => const Success<Person>(Person(
              id: 'person-9',
              name: 'Me',
              email: 'me@example.com',
              role: Role.systemAdmin,
            )));

    // When
    await pump(tester, role: 0, initialLocation: '/persons/person-9');

    // Then — the own-record rules hold (AF-19d; UI-36 hides the card)
    expect(find.text('Account emails'), findsNothing);
    expect(find.text('Delete'), findsNothing);
  });

  testWidgets('GivenNoScope_WhenDeleted_ThenSystemAdminsOpens', (tester) async {
    // Given
    when(() => repository.getById('person-1', includeDeleted: true))
        .thenAnswer((_) async => const Success<Person>(Person(
              id: 'person-1',
              name: 'Grace',
              email: 'grace@example.com',
              role: Role.systemAdmin,
            )));
    when(() => repository.delete('person-1'))
        .thenAnswer((_) async => const Success<void>(null));
    await pump(tester, role: 0, initialLocation: '/persons/person-1');

    // When
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    // Then
    expect(find.text('system admins'), findsOneWidget);
  });
```

  - Match the existing delete test's way of confirming. Copy `GivenADeletedPerson_WhenDeleted_ThenTheListingOpens`'s taps and mocks. If the delete method has a different name in the mock, use the existing test's.
  - The existing own-record tests show how "Delete" is absent; reuse their finders.
- [ ] **Step 3: Run them to see them fail.** Expected: FAIL. The route rule answers true, `scopeId` is required, and the route doesn't exist.
- [ ] **Step 4: Make `scopeId` optional.**

```dart
  const PersonDetailScreen({
    required this.personId,
    this.scopeId,
    super.key,
  });

  /// The scope the person was reached through, or `null` when they were
  /// opened from the System Admins list (UI-38), which has no scope.
  final String? scopeId;
```

  In `build`:

```dart
    final scopeId = widget.scopeId;
    final backToListing = scopeId == null
        ? '/system-admins'
        : '/scopes/$scopeId/persons';
    final backTooltip = scopeId == null
        ? 'Back to System Admins'
        : 'Back to the listing';
```

  In the `PersonDeleted` listener, reload the scope's list only when there is a scope:

```dart
        if (next is PersonDeleted) {
          if (scopeId != null) {
            ref.read(personListControllerProvider(scopeId).notifier).load();
          }
          context.go(backToListing);
        }
```

  - Pass `backTooltip: backTooltip` to `AppShell`.
  - Set `currentRoute: scopeId == null ? '/' : '/scopes'`.
  - Leave the "Back to the listing" labels inside the not-found and failure states as they are. They go to `backToListing`, which is now correct for both cases.
- [ ] **Step 5: Add the route and the rule.** In `router.dart`:

```dart
      GoRoute(
        path: '/persons/:personId',
        builder: (context, state) =>
            PersonDetailScreen(personId: state.pathParameters['personId']!),
      ),
```

  In `route_access.dart`, next to `/system-admins`:

```dart
  // UI-38's person page has no scope to authorise against. A Scope Admin
  // reaches the persons they may see through their scopes instead.
  final String p when p.startsWith('/persons/') => role == Role.systemAdmin,
```

- [ ] **Step 6: Run the tests, then the gate.** Expected: PASS. All the existing scoped person-page tests stay green.
- [ ] **Step 7: Commit.**

```bash
git add lib/features/persons/presentation/person_detail_screen.dart lib/app/router.dart lib/app/route_access.dart test/features/persons/presentation/person_detail_screen_test.dart test/app/route_access_test.dart
git commit   # subject: feat(ui-38): open a person without a scope
```

---

### Task 5: The Home tile

**Files:**
- Modify: `lib/features/home/domain/dashboard.dart` (`DashboardStats`)
- Modify: `lib/features/home/presentation/dashboard_controller.dart` (`load`)
- Modify: `lib/features/home/presentation/home_screen.dart` (`_LoadedDashboard`, ~line 270-310)
- Modify: `test/support/dashboard_fakes.dart`
- Test: `test/features/home/dashboard_controller_test.dart`, `test/features/home/home_screen_test.dart`

**Interfaces:**
- Consumes: Task 1's `listSystemAdmins`; `sessionControllerProvider` (`lib/features/auth/presentation/session_controller.dart`) and `Authenticated` / `principal.isSystemAdmin` (`lib/features/auth/domain/session.dart`).
- Produces: `DashboardStats.systemAdmins` (`int?`).

- [ ] **Step 1: Teach the fake.** In `dashboard_fakes.dart`:
  - add a field `final int? systemAdmins;` (default `1`) to `FakeDashboardRepositories`;
  - add this override to `_Persons`:

```dart
  @override
  Future<Result<Page<PersonSummary>>> listSystemAdmins({
    String? name,
    String? email,
    int pageNumber = 1,
    int pageSize = 20,
  }) async => _count<PersonSummary>(fakes.systemAdmins);
```

- [ ] **Step 2: Write the failing tests.**
  - **`dashboard_controller_test.dart`:** a System Admin session reads the count into `stats.systemAdmins`.
    - Use the file's existing way of signing in. If it has none, override `sessionControllerProvider` the way `home_screen_test.dart` does.
    - A Scope Admin session doesn't call `listSystemAdmins` and leaves `systemAdmins` null.
  - **`home_screen_test.dart`:**

```dart
  testWidgets('GivenASystemAdmin_WhenHomeOpens_ThenTheSystemAdminsTileShowsTheCount', (tester) async {
    // Given — three System Admins
    // (build the harness with FakeDashboardRepositories(systemAdmins: 3) as the
    // other System Admin tests in this file do)

    // Then
    expect(find.text('System Admins'), findsOneWidget);
    expect(find.text('Full access to every scope'), findsOneWidget);
    expect(find.text('3'), findsWidgets);
  });

  testWidgets('GivenTheSystemAdminsTile_WhenTapped_ThenTheListOpens', (tester) async {
    // Given — a System Admin home, with a /system-admins route in the harness
    // When
    await tester.tap(find.text('System Admins'));
    await tester.pumpAndSettle();
    // Then
    expect(find.text('system admins'), findsOneWidget);
  });

  testWidgets('GivenTheCountFails_WhenHomeOpens_ThenTheTileStillOpensTheList', (tester) async {
    // Given — FakeDashboardRepositories(systemAdmins: null)
    // Then
    expect(find.byTooltip('Could not be read'), findsWidgets);
    await tester.tap(find.text('System Admins'));
    await tester.pumpAndSettle();
    expect(find.text('system admins'), findsOneWidget);
  });

  testWidgets('GivenAScopeAdmin_WhenHomeOpens_ThenNoSystemAdminsTile', (tester) async {
    // Given — a Scope Admin home as the file's Scope Admin tests build it
    // Then
    expect(find.text('System Admins'), findsNothing);
  });
```

  Fill each Given with the file's own harness calls, copying the nearest existing System Admin or Scope Admin test. If the harness's router lacks a `/system-admins` route, add one that renders `Text('system admins')`.
- [ ] **Step 3: Run them to see them fail.** Expected: FAIL. `systemAdmins` doesn't exist and there is no tile.
- [ ] **Step 4: Add the stat.** In `DashboardStats`, add the constructor parameter `this.systemAdmins` and:

```dart
  /// How many System Admins the system has (UI-38), or `null` when that could
  /// not be read or the caller is not a System Admin and was never told.
  final int? systemAdmins;
```

- [ ] **Step 5: Read it in parallel.** In `DashboardController.load`, next to `ping`:

```dart
    final session = ref.read(sessionControllerProvider);
    final isSystemAdmin =
        session is Authenticated && session.principal.isSystemAdmin;
    // UC-07 read (e) is a System Admin's only; nobody else is asked.
    final systemAdmins = isSystemAdmin
        ? ref.read(personRepositoryProvider).listSystemAdmins(pageSize: 1)
        : null;
```

  Then, when building the stats:

```dart
            systemAdmins: systemAdmins == null
                ? null
                : (await systemAdmins).valueOrNull?.totalItems,
```

- [ ] **Step 6: Add the tile.** In `_LoadedDashboard`, between the Google users tile and `_ApiStatusTile`:

```dart
            if (isSystemAdmin)
              _StatTile(
                label: 'System Admins',
                icon: Icons.admin_panel_settings_outlined,
                value: _figure(stats.systemAdmins),
                tooltip: stats.systemAdmins == null ? 'Could not be read' : null,
                caption: 'Full access to every scope',
                onTap: () => context.go('/system-admins'),
              ),
```

  If `_StatGrid`'s `children` can't take a collection `if`, build the list first.
- [ ] **Step 7: Run the tests, then the gate.** Expected: PASS, with every existing dashboard and Home test green.
- [ ] **Step 8: Commit.**

```bash
git add lib/features/home/domain/dashboard.dart lib/features/home/presentation/dashboard_controller.dart lib/features/home/presentation/home_screen.dart test/support/dashboard_fakes.dart test/features/home/dashboard_controller_test.dart test/features/home/home_screen_test.dart
git commit   # subject: feat(ui-38): count the system admins on home
```

---

### Task 6: Document UI-38

**Files:**
- Modify: `docs/requirements/Use Case Specification Document.md`, `docs/requirements/System Requirements Document.md`, `README.md`, `CHANGELOG.md`, `docs/requirements/Development Workflow Document.md`, `docs/superpowers/specs/2026-10-15-system-admins-list-design.md`

- [ ] **Step 1: Use Case Specification Document.** Add `### UI-38: List System Admins` after UI-37, in UI-37's structure:
  - **Actor:** System Admin. **Traces to:** UC-07 (View Person), read (e).
  - **Placement:** the **System Admins** tile on Home opens `/system-admins`. Rows open `/persons/:personId`.
  - **Main flow:**
    1. The admin opens the tile.
    2. The client calls `GET /api/persons/system-admins` with the page, page size and filters.
    3. Each row shows the name and email; the signed-in admin's own row is marked "(you)".
    4. The admin searches by name or email (Enter or **Search**), which returns to page 1, or pages.
    5. The admin opens a row, and the person page opens without a scope. Its back control goes to the list.
  - **Alternative flows:**
    - AF-38a: no System Admins ("No System Admins.").
    - AF-38b: no matches ("No System Admins match.", **Clear filters**).
    - AF-38c: 403, the forbidden state with **Back to Home**.
    - AF-38d: another failure, the errors with **Retry**, keeping the filters.
    - AF-38e: 429, the API's message with its hint (FR-UX-09).
  - Also add:
    - the inventory row;
    - a diagram node with an SA edge;
    - the traceability row → FR-PE-12;
    - in UI-18 (view a person), a sentence that a System Admin may also open a person at `/persons/:personId` from UI-38, where the back control returns to the System Admins list.
- [ ] **Step 2: System Requirements Document.**
  - FR-PE-12, as in spec §8.
  - The route rows for `/system-admins` and `/persons/:personId`.
  - The Authorization Matrix rows: System Admin only.
  - Add UI-38 to FR-UX-04, FR-UX-06 and FR-UX-09.
- [ ] **Step 3: README.**
  - Remove the "List System Admins" row from "Needs Heimdall API work".
  - Add `| UI-38: List System Admins | ✅ | [#149](https://github.com/artur-rios/heimdall-ui/issues/149) |` to the person-management table.
  - Change "UI-01 … UI-37" to "UI-01 … UI-38" here and in `Development Workflow Document.md`.
- [ ] **Step 4: CHANGELOG.** Under `[Unreleased]` → `### Added`: "**System Admins list** — a System Admin can see and search the system's System Admins from Home, and open their person pages."
- [ ] **Step 5: Spec amendments.**
  - Spec §4: replace "It refuses overlapping loads, using the busy pattern of UI-35 and UI-37." with "Overlapping requests queue the newest query, as UI-16 does, building every change from the queued query."
  - Replace "(Enter or the field's search button)" with "(Enter or the **Search** button, as UI-16)".
  - Spec §5: replace "After an edit or a delete, the screen refreshes the System Admins list provider, if it is alive, instead of the scope's list." with "After a delete it goes to `/system-admins`, which loads fresh; the list is disposed while the person page is open."
  - At the end, add: "Amended while planning: Decisions 1–3 of the plan."
- [ ] **Step 6: Gate and commit.**

```bash
git add "docs/requirements/Use Case Specification Document.md" "docs/requirements/System Requirements Document.md" README.md CHANGELOG.md "docs/requirements/Development Workflow Document.md" docs/superpowers/specs/2026-10-15-system-admins-list-design.md
git commit   # subject: docs(ui-38): specify the system admins list
```

---

## Verification

- [ ] The full gate passes. `git log --oneline origin/develop..HEAD` shows the spec, the plan and Tasks 1–6.
- [ ] `grep -rn "system-admins" lib` shows the repository call, the route, the rule and the tile.
