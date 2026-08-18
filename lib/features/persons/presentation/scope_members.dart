import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/envelope.dart';
import '../../../core/result/result.dart';
import '../../profile/presentation/profile_controller.dart';
import '../domain/person.dart';

/// Everyone associated with a scope: its users and the admins who own it.
///
/// UI-21 and UI-22 pick an application's owner from this, and AF-21c is why it
/// is the two listings rather than a free-text identifier — the API refuses an
/// owner who is not of the scope, and offering only those who are is what
/// keeps the interface from inviting the refusal.
final FutureProviderFamily<List<Person>, String> scopeMembersProvider =
    FutureProvider.family<List<Person>, String>((ref, scopeId) async {
      final repository = ref.watch(personRepositoryProvider);

      // The two listings are independent: a scope with no users still has
      // owners, so either failing must not hide the other.
      final results = await Future.wait<Result<Page<Person>>>(
        <Future<Result<Page<Person>>>>[
          repository.listScopePersons(scopeId: scopeId, pageSize: 100),
          repository.listScopeOwners(scopeId: scopeId, pageSize: 100),
        ],
      );

      final byId = <String, Person>{};

      for (final result in results) {
        for (final person in result.valueOrNull?.items ?? const <Person>[]) {
          byId[person.id] = person;
        }
      }

      final members = byId.values.toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      return List<Person>.unmodifiable(members);
    });
