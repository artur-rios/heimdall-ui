import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/core/network/envelope.dart';
import 'package:heimdall_ui/core/result/result.dart';
import 'package:heimdall_ui/features/auth/domain/session.dart';
import 'package:heimdall_ui/features/persons/domain/person.dart';
import 'package:heimdall_ui/features/persons/domain/person_repository.dart';
import 'package:heimdall_ui/features/persons/presentation/scope_members.dart';
import 'package:heimdall_ui/features/profile/presentation/profile_controller.dart';
import 'package:mocktail/mocktail.dart';

class _MockPersonRepository extends Mock implements PersonRepository {}

Person _person(String id, String name, {bool isDeleted = false}) => Person(
  id: id,
  name: name,
  email: '$id@example.com',
  role: Role.scopeAdmin,
  isDeleted: isDeleted,
);

void main() {
  late _MockPersonRepository repository;

  ProviderContainer containerAnswering(Result<Page<Person>> result) {
    when(
      () => repository.listScopeOwners(
        scopeId: any(named: 'scopeId'),
        name: any(named: 'name'),
        email: any(named: 'email'),
        includeDeleted: any(named: 'includeDeleted'),
        pageNumber: any(named: 'pageNumber'),
        pageSize: any(named: 'pageSize'),
      ),
    ).thenAnswer((_) async => result);

    final container = ProviderContainer(
      overrides: <Override>[
        personRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    return container;
  }

  setUp(() {
    repository = _MockPersonRepository();
  });

  test('GivenOwners_WhenRead_ThenTheLiveOnesAreListedByName', () async {
    // Given
    final container = containerAnswering(
      Success<Page<Person>>(
        Page<Person>(
          items: <Person>[
            _person('p2', 'Zoe'),
            _person('p1', 'ada'),
            _person('p3', 'Gone', isDeleted: true),
          ],
          pageNumber: 1,
          pageSize: 100,
          totalItems: 3,
          totalPages: 1,
        ),
      ),
    );

    // When
    final members = await container.read(scopeMembersProvider('s').future);

    // Then
    expect(members.map((person) => person.name), <String>['ada', 'Zoe']);
  });

  // "Nobody can own an application here" would be the wrong answer to a
  // listing that simply could not be read.
  test('GivenAnUnreadableListing_WhenRead_ThenItIsAnError', () async {
    // Given
    const failure = Failure(kind: FailureKind.network, errors: <String>[]);
    final container = containerAnswering(
      const FailureResult<Page<Person>>(failure),
    );

    // When
    final read = container.read(scopeMembersProvider('s').future);

    // Then
    await expectLater(read, throwsA(same(failure)));
  });
}
