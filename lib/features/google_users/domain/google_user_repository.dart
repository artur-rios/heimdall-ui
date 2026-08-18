import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/result/result.dart';

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
}

/// Overridden at start-up with the client-backed implementation, and in tests
/// with a fake.
final Provider<GoogleUserRepository> googleUserRepositoryProvider =
    Provider<GoogleUserRepository>(
      (ref) => throw UnimplementedError(
        'googleUserRepositoryProvider must be overridden',
      ),
    );
