import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The key a calling application writes the target scope under.
///
/// Heimdall UI is opened from the applications that use Heimdall's services,
/// and the scope being entered is theirs to decide — there is no screen here
/// that could ask for it, and no endpoint an anonymous caller could list them
/// from.
const String scopeStorageKey = 'heimdall.scopeId';

/// Where the `PublicId` of the scope the caller is acting in comes from.
///
/// Read on demand rather than captured once: the calling application may
/// rewrite it between one attempt and the next, and a value cached at start-up
/// would then be the wrong one.
abstract interface class ScopeSource {
  String? read();
}

/// A scope fixed for the lifetime of the process.
///
/// Backs the non-web targets, where there is no calling web application to
/// write anything and a build targets one deployment.
class FixedScopeSource implements ScopeSource {
  const FixedScopeSource(this._scopeId);

  final String? _scopeId;

  @override
  String? read() {
    final scopeId = _scopeId;

    return (scopeId == null || scopeId.isEmpty) ? null : scopeId;
  }
}

/// Overridden at start-up with the platform's source, and in tests with a fake.
final Provider<ScopeSource> scopeSourceProvider = Provider<ScopeSource>(
  (ref) => throw UnimplementedError('scopeSourceProvider must be overridden'),
);
