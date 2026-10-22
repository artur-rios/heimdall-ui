import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/core/network/envelope.dart';
import 'package:heimdall_ui/core/result/result.dart';
import 'package:heimdall_ui/features/auth/domain/session.dart';
import 'package:heimdall_ui/features/persons/domain/person.dart';
import 'package:heimdall_ui/features/persons/domain/person_repository.dart';
import 'package:heimdall_ui/features/profile/presentation/profile_controller.dart';
import 'package:heimdall_ui/features/scopes/presentation/scope_users_controller.dart';
import 'package:mocktail/mocktail.dart';

class _MockPersonRepository extends Mock implements PersonRepository {}

const _alan = Person(
  id: 'person-3',
  name: 'Alan',
  email: 'alan@example.com',
  role: Role.user,
);

Page<Person> _page(List<Person> items, {int pageNumber = 1}) => Page<Person>(
  items: items,
  pageNumber: pageNumber,
  pageSize: 20,
  totalItems: 25,
  totalPages: 2,
);

void main() {
  late _MockPersonRepository repository;
  late ProviderContainer container;

  ScopeUsersController controllerUnderTest() {
    container = ProviderContainer(
      overrides: <Override>[
        personRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    return container.read(scopeUsersControllerProvider('scope-1').notifier);
  }

  void answerWith(Result<Page<Person>> result) {
    when(
      () => repository.listScopePersons(
        scopeId: any(named: 'scopeId'),
        name: any(named: 'name'),
        email: any(named: 'email'),
        includeDeleted: any(named: 'includeDeleted'),
        pageNumber: any(named: 'pageNumber'),
        pageSize: any(named: 'pageSize'),
      ),
    ).thenAnswer((_) async => result);
  }

  setUp(() {
    repository = _MockPersonRepository();
    answerWith(Success<Page<Person>>(_page(<Person>[_alan])));
  });

  test('GivenAScope_WhenLoaded_ThenTheFirstPageOfItsUsersIsRead', () async {
    // Given
    final controller = controllerUnderTest();

    // When
    await controller.load();

    // Then
    final state = container.read(scopeUsersControllerProvider('scope-1'));
    expect(state, isA<ScopeUsersLoaded>());
    expect((state as ScopeUsersLoaded).page.totalItems, 25);
    verify(
      () => repository.listScopePersons(
        scopeId: 'scope-1',
        name: null,
        email: null,
        pageNumber: 1,
      ),
    ).called(1);
  });

  test('GivenALoadedList_WhenThePageChanges_ThenThatPageIsRead', () async {
    // Given
    final controller = controllerUnderTest();
    await controller.load();

    // When
    await controller.goToPage(2);

    // Then
    verify(
      () => repository.listScopePersons(
        scopeId: 'scope-1',
        name: null,
        email: null,
        pageNumber: 2,
      ),
    ).called(1);
  });

  test('GivenATypedName_WhenSearched_ThenItFiltersByNameFromPageOne', () async {
    // Given
    final controller = controllerUnderTest();
    await controller.load();
    await controller.goToPage(2);

    // When
    await controller.search(' Alan ');

    // Then
    verify(
      () => repository.listScopePersons(
        scopeId: 'scope-1',
        name: 'Alan',
        email: null,
        pageNumber: 1,
      ),
    ).called(1);
  });

  test('GivenATypedAddress_WhenSearched_ThenItFiltersByEmail', () async {
    // Given
    final controller = controllerUnderTest();
    await controller.load();

    // When
    await controller.search('alan@example.com');

    // Then
    verify(
      () => repository.listScopePersons(
        scopeId: 'scope-1',
        name: null,
        email: 'alan@example.com',
        pageNumber: 1,
      ),
    ).called(1);
  });

  test('GivenAFailingApi_WhenLoaded_ThenTheQueryIsKeptForARetry', () async {
    // Given
    answerWith(
      const FailureResult<Page<Person>>(
        Failure(kind: FailureKind.network, errors: <String>[]),
      ),
    );
    final controller = controllerUnderTest();

    // When
    await controller.search('Alan');

    // Then
    final state = container.read(scopeUsersControllerProvider('scope-1'));
    expect(state, isA<ScopeUsersFailed>());
    expect(state.query.search, 'Alan');
  });

  test('GivenNoSearch_ThenTheQueryIsNotFiltered', () {
    expect(const ScopeUsersQuery().isFiltered, isFalse);
    expect(const ScopeUsersQuery(search: ' a ').isFiltered, isTrue);
  });
}
