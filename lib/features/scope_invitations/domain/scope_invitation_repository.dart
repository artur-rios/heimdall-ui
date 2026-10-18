import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/envelope.dart';
import '../../../core/result/result.dart';
import 'scope_invitation.dart';

/// The scope owner invitation reads and answers UI-14 and UI-39 depend on.
///
/// Every refusal of an answer or a withdrawal for an invitation that has
/// ended, expired or is somebody else's arrives as [FailureKind.notFound], in
/// the API's own words.
abstract interface class ScopeInvitationRepository {
  /// One page of a scope's open owner invitations (UC-58).
  Future<Result<Page<OwnerInvitation>>> listForScope(
    String scopeId, {
    int pageNumber = 1,
    int pageSize = 50,
  });

  /// Withdraws one of them (UC-58).
  Future<Result<void>> withdraw(String scopeId, String invitationId);

  /// One page of the signed-in administrator's own open invitations (UC-59).
  Future<Result<Page<ScopeInvitation>>> listMine({
    int pageNumber = 1,
    int pageSize = 50,
  });

  /// Accepts one, which makes the caller an owner of its scope (UC-60).
  Future<Result<void>> accept(String invitationId);

  /// Declines one (UC-61).
  Future<Result<void>> decline(String invitationId);
}

final Provider<ScopeInvitationRepository> scopeInvitationRepositoryProvider =
    Provider<ScopeInvitationRepository>(
      (ref) => throw UnimplementedError(
        'scopeInvitationRepositoryProvider must be overridden',
      ),
    );
