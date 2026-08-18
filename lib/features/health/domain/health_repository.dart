import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/result/result.dart';
import 'health.dart';

/// The health operations the interface depends on.
abstract interface class HealthRepository {
  /// The liveness check, which anyone may call.
  ///
  /// Returns whatever the API answered with, because the point of a liveness
  /// check is that it answered at all.
  Future<Result<String>> ping();

  /// The detailed report, which only a System Admin may read.
  ///
  /// A `403` for a Scope Admin is the expected answer rather than a fault, and
  /// the screen says so.
  Future<Result<Health>> detailed();
}

/// Overridden at start-up with the client-backed implementation, and in tests
/// with a fake.
final Provider<HealthRepository> healthRepositoryProvider =
    Provider<HealthRepository>(
      (ref) => throw UnimplementedError(
        'healthRepositoryProvider must be overridden',
      ),
    );
