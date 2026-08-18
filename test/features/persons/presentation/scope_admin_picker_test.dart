import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/app/theme.dart';
import 'package:heimdall_ui/core/network/envelope.dart' as envelope;
import 'package:heimdall_ui/core/result/result.dart';
import 'package:heimdall_ui/features/persons/domain/person.dart';
import 'package:heimdall_ui/features/persons/domain/person_repository.dart';
import 'package:heimdall_ui/features/persons/presentation/scope_admin_picker.dart';
import 'package:heimdall_ui/features/persons/presentation/scope_admin_picker_controller.dart';
import 'package:heimdall_ui/features/profile/presentation/profile_controller.dart';
import 'package:mocktail/mocktail.dart';

class _MockPersonRepository extends Mock implements PersonRepository {}

const _ada = PersonSummary(
  id: 'person-1',
  name: 'Ada',
  email: 'ada@example.com',
);

const _grace = PersonSummary(
  id: 'person-2',
  name: 'Grace',
  email: 'grace@example.com',
);

const _offline = FailureResult<envelope.Page<PersonSummary>>(
  Failure(kind: FailureKind.network, errors: <String>[]),
);

Result<envelope.Page<PersonSummary>> _listing(List<PersonSummary> items) =>
    Success<envelope.Page<PersonSummary>>(
      envelope.Page<PersonSummary>(
        items: items,
        pageNumber: 1,
        pageSize: 50,
        totalItems: items.length,
        totalPages: 1,
      ),
    );

const Size _compact = Size(400, 900);
const Size _expanded = Size(1400, 900);

void main() {
  late _MockPersonRepository repository;
  late ProviderContainer container;

  void answerWith(Result<envelope.Page<PersonSummary>> result) {
    when(
      () => repository.listScopeAdmins(
        name: any(named: 'name'),
        email: any(named: 'email'),
        excludeOwnersOfScopeId: any(named: 'excludeOwnersOfScopeId'),
        pageNumber: any(named: 'pageNumber'),
        pageSize: any(named: 'pageSize'),
      ),
    ).thenAnswer((_) async => result);
  }

  ProviderContainer containerUnderTest() {
    container = ProviderContainer(
      overrides: <Override>[
        personRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    return container;
  }

  /// Pumps a screen whose one control opens the picker, so a test can assert
  /// what the picker answered with as well as what it showed.
  Future<void> pump(
    WidgetTester tester, {
    Size size = _expanded,
    ThemeData? theme,
    String? excludeOwnersOfScopeId,
    Set<String> excludeIds = const <String>{},
    void Function(PersonSummary?)? onChosen,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: containerUnderTest(),
        child: MaterialApp(
          theme: theme ?? buildLightTheme(),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  final chosen = await showScopeAdminPicker(
                    context: context,
                    excludeOwnersOfScopeId: excludeOwnersOfScopeId,
                    excludeIds: excludeIds,
                  );
                  onChosen?.call(chosen);
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  setUp(() {
    repository = _MockPersonRepository();
    answerWith(_listing(<PersonSummary>[_ada, _grace]));
  });

  test('GivenAListing_WhenRead_ThenTheCandidatesAreOffered', () async {
    // Given
    final container = containerUnderTest();

    // When
    await container
        .read(scopeAdminPickerControllerProvider('').notifier)
        .search();

    // Then
    final state =
        container.read(scopeAdminPickerControllerProvider(''))
            as ScopeAdminsLoaded;
    expect(state.candidates, hasLength(2));
  });

  // One field is what a picker wants; which filter it becomes is this
  // controller's decision, not the user's.
  test('GivenAnAddress_WhenSearched_ThenItTravelsAsTheEmailFilter', () async {
    // Given
    final container = containerUnderTest();

    // When
    await container
        .read(scopeAdminPickerControllerProvider('').notifier)
        .search('ada@example.com');

    // Then
    verify(
      () => repository.listScopeAdmins(
        name: null,
        email: 'ada@example.com',
        excludeOwnersOfScopeId: any(named: 'excludeOwnersOfScopeId'),
        pageNumber: any(named: 'pageNumber'),
        pageSize: any(named: 'pageSize'),
      ),
    ).called(1);
  });

  test('GivenAName_WhenSearched_ThenItTravelsAsTheNameFilter', () async {
    // Given
    final container = containerUnderTest();

    // When
    await container
        .read(scopeAdminPickerControllerProvider('').notifier)
        .search('Ada');

    // Then
    verify(
      () => repository.listScopeAdmins(
        name: 'Ada',
        email: null,
        excludeOwnersOfScopeId: any(named: 'excludeOwnersOfScopeId'),
        pageNumber: any(named: 'pageNumber'),
        pageSize: any(named: 'pageSize'),
      ),
    ).called(1);
  });

  // AF-14c — the exclusion is the API's to apply, so it has to reach it.
  test('GivenAScopeToExclude_WhenSearched_ThenItIsSent', () async {
    // Given
    final container = containerUnderTest();

    // When
    await container
        .read(scopeAdminPickerControllerProvider('scope-1').notifier)
        .search();

    // Then
    verify(
      () => repository.listScopeAdmins(
        name: any(named: 'name'),
        email: any(named: 'email'),
        excludeOwnersOfScopeId: 'scope-1',
        pageNumber: any(named: 'pageNumber'),
        pageSize: any(named: 'pageSize'),
      ),
    ).called(1);
  });

  test('GivenNoScopeToExclude_WhenSearched_ThenNoExclusionIsSent', () async {
    // Given
    final container = containerUnderTest();

    // When
    await container
        .read(scopeAdminPickerControllerProvider('').notifier)
        .search();

    // Then
    verify(
      () => repository.listScopeAdmins(
        name: any(named: 'name'),
        email: any(named: 'email'),
        excludeOwnersOfScopeId: null,
        pageNumber: any(named: 'pageNumber'),
        pageSize: any(named: 'pageSize'),
      ),
    ).called(1);
  });

  test('GivenAFailedListing_WhenRead_ThenItIsUnavailable', () async {
    // Given
    answerWith(_offline);
    final container = containerUnderTest();

    // When
    await container
        .read(scopeAdminPickerControllerProvider('').notifier)
        .search();

    // Then
    expect(
      container.read(scopeAdminPickerControllerProvider('')),
      isA<ScopeAdminsUnavailable>(),
    );
  });

  testWidgets('GivenCandidates_WhenOpened_ThenTheyAreListed', (tester) async {
    // Given / When
    await pump(tester);

    // Then
    expect(find.text('Ada'), findsOneWidget);
    expect(find.text('grace@example.com'), findsOneWidget);
  });

  testWidgets('GivenACandidate_WhenChosen_ThenTheyAreAnsweredWith', (
    tester,
  ) async {
    // Given
    PersonSummary? chosen;
    await pump(tester, onChosen: (value) => chosen = value);

    // When
    await tester.tap(find.widgetWithText(ListTile, 'Ada'));
    await tester.pumpAndSettle();

    // Then
    expect(chosen?.id, 'person-1');
  });

  testWidgets('GivenThePicker_WhenCancelled_ThenNobodyIsAnsweredWith', (
    tester,
  ) async {
    // Given
    PersonSummary? chosen;
    var answered = false;
    await pump(
      tester,
      onChosen: (value) {
        chosen = value;
        answered = true;
      },
    );

    // When
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    // Then
    expect(answered, isTrue);
    expect(chosen, isNull);
  });

  // What the calling screen has already collected is not the API's to know.
  testWidgets('GivenAnExcludedIdentifier_WhenOpened_ThenItIsNotOffered', (
    tester,
  ) async {
    // Given / When
    await pump(tester, excludeIds: <String>{'person-1'});

    // Then
    expect(find.widgetWithText(ListTile, 'Ada'), findsNothing);
    expect(find.widgetWithText(ListTile, 'Grace'), findsOneWidget);
  });

  testWidgets('GivenNobodyToOffer_WhenOpened_ThenTheEmptyStateIsShown', (
    tester,
  ) async {
    // Given
    answerWith(_listing(<PersonSummary>[]));

    // When
    await pump(tester);

    // Then
    expect(find.text('No Scope Admins to offer'), findsOneWidget);
  });

  testWidgets('GivenAQuery_WhenSubmitted_ThenTheListingIsNarrowed', (
    tester,
  ) async {
    // Given
    await pump(tester);
    answerWith(_listing(<PersonSummary>[_ada]));

    // When
    await tester.enterText(find.byType(TextField), 'Ada');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    // Then
    expect(find.widgetWithText(ListTile, 'Grace'), findsNothing);
  });

  // Naming an owner was possible before this listing existed, and a listing
  // that cannot be read must not take that away.
  testWidgets('GivenAFailedListing_WhenOpened_ThenAnIdentifierIsAccepted', (
    tester,
  ) async {
    // Given
    answerWith(_offline);
    PersonSummary? chosen;
    await pump(tester, onChosen: (value) => chosen = value);

    // When
    await tester.enterText(find.byType(TextField), 'person-7');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Use this identifier'));
    await tester.pumpAndSettle();

    // Then
    expect(chosen?.id, 'person-7');
  });

  testWidgets('GivenAFailedListing_WhenRetried_ThenTheCandidatesArrive', (
    tester,
  ) async {
    // Given
    answerWith(_offline);
    await pump(tester);
    answerWith(_listing(<PersonSummary>[_ada]));

    // When
    await tester.tap(find.widgetWithText(TextButton, 'Retry'));
    await tester.pumpAndSettle();

    // Then
    expect(find.widgetWithText(ListTile, 'Ada'), findsOneWidget);
  });

  testWidgets('GivenACompactWindow_WhenOpened_ThenTheCandidatesAreListed', (
    tester,
  ) async {
    // Given / When
    await pump(tester, size: _compact);

    // Then
    expect(find.widgetWithText(ListTile, 'Ada'), findsOneWidget);
  });

  testWidgets('GivenTheDarkTheme_WhenOpened_ThenTheCandidatesAreListed', (
    tester,
  ) async {
    // Given / When
    await pump(tester, theme: buildDarkTheme());

    // Then
    expect(find.widgetWithText(ListTile, 'Ada'), findsOneWidget);
  });
}
