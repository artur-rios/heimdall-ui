import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/result/result.dart';
import 'data_rights.dart';

/// The data subject's own rights over what the API holds about them.
///
/// Every operation acts on the caller: the API reads the subject from the
/// bearer token, and none of these requests names anybody. That is also why a
/// subject-rights-only token (UI-30) is admitted to them and to nothing else.
abstract interface class DataRightsRepository {
  /// UC-41 — a copy of everything held about the caller.
  Future<Result<DataExport>> exportMyData();

  /// UC-42 — asks for the caller's identity to be erased, confirmed with
  /// [credential]. A bearer token alone is not enough for something that
  /// cannot be undone.
  Future<Result<ErasureRequest>> requestErasure(ErasureCredential credential);

  /// UC-44 — restricts processing of the caller's own identity on [ground].
  ///
  /// The API suspends the account at once, and stops admitting the token that
  /// asked to anything but the rights endpoints.
  Future<Result<void>> restrictProcessing(RestrictionGround ground);

  /// UC-45 — lifts the restriction on processing the caller's own identity.
  Future<Result<void>> liftOwnRestriction();
}

/// Overridden at start-up with the client-backed implementation, and in tests
/// with a fake.
final Provider<DataRightsRepository> dataRightsRepositoryProvider =
    Provider<DataRightsRepository>(
      (ref) => throw UnimplementedError(
        'dataRightsRepositoryProvider must be overridden',
      ),
    );
