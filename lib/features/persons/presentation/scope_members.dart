import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../profile/presentation/profile_controller.dart';
import '../domain/person.dart';

/// The people who may own one of a scope's applications: its owners.
///
/// UI-21 and UI-22 pick an application's owner from this, and AF-21c is why it
/// is a listing rather than a free-text identifier — the API refuses an owner
/// who is not a Scope Admin owning the scope (FR-AP-03, `OwnerNotValidForScope`),
/// and offering only those is what keeps the interface from inviting that
/// refusal. The scope's Users are deliberately absent: the API refuses every
/// one of them as an owner.
final FutureProviderFamily<List<Person>, String> scopeMembersProvider =
    FutureProvider.family<List<Person>, String>((ref, scopeId) async {
      final result = await ref
          .watch(personRepositoryProvider)
          .listScopeOwners(scopeId: scopeId, pageSize: 100);

      final members = <Person>[
        ...?result.valueOrNull?.items.where((person) => !person.isDeleted),
      ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      return List<Person>.unmodifiable(members);
    });
