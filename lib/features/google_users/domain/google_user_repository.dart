import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/envelope.dart';
import '../../../core/result/result.dart';
import 'google_user.dart';

/// The Google User operations the interface depends on.
///
/// UI-15 asks it one question — how many a scope holds — because disabling
/// Google Sign-In is a different warning when there are accounts that will
/// stop working. UI-28 and UI-29 extend it with the listing and the deletions.
abstract interface class GoogleUserRepository {
  /// How many Google Users the scope holds.
  ///
  /// Reads one page of one item and takes the API's own total, so the answer
  /// costs the same whether the scope holds none or thousands.
  Future<Result<int>> countIn(String scopeId);

  /// Reads one page of a scope's Google Users.
  Future<Result<Page<GoogleUser>>> list({
    required String scopeId,
    String? name,
    String? email,
    bool includeDeleted = false,
    int pageNumber = 1,
    int pageSize = 20,
  });

  /// Reads one Google User.
  ///
  /// [includeDeleted] is on by default for the detail screen, so a logically
  /// deleted record can still be looked at.
  Future<Result<GoogleUser>> getById({
    required String scopeId,
    required String id,
    bool includeDeleted = true,
  });
}

/// Overridden at start-up with the client-backed implementation, and in tests
/// with a fake.
final Provider<GoogleUserRepository> googleUserRepositoryProvider =
    Provider<GoogleUserRepository>(
      (ref) => throw UnimplementedError(
        'googleUserRepositoryProvider must be overridden',
      ),
    );
