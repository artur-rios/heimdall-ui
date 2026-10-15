import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ids/public_id.dart';

/// The session storage key the target scope is kept under on the web.
///
/// Heimdall UI is opened from the applications that use Heimdall's services,
/// and the scope being entered is theirs to decide — there is no screen here
/// that could ask for it, and no endpoint an anonymous caller could list them
/// from. A caller hands it over as `?scope=<PublicId>` on the entry URL, and
/// start-up copies it here (see `takeEntryLink`); a caller on the UI's own
/// origin may still write it directly, as before.
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

/// A scope read from storage on every use, with a build-time fallback.
///
/// Backs the web, where it reads session storage: what start-up copied from
/// a `?scope=` on the entry URL, or what a caller on the UI's own origin wrote
/// there itself. Both are held to the same rule — a value that is not a
/// `PublicId` is ignored, as the URL's is — and then [fallback] applies.
class StoredScopeSource implements ScopeSource {
  const StoredScopeSource(this._stored, {this.fallback});

  /// Reads the stored value; called on every use, so a caller may change it
  /// between one attempt and the next.
  final String? Function() _stored;

  /// Used when nothing usable is stored: a build opened directly rather than
  /// handed off to.
  final String? fallback;

  @override
  String? read() {
    final stored = _stored();

    if (stored != null && isPublicId(stored)) {
      return stored;
    }

    return FixedScopeSource(fallback).read();
  }
}

/// Overridden at start-up with the platform's source, and in tests with a fake.
final Provider<ScopeSource> scopeSourceProvider = Provider<ScopeSource>(
  (ref) => throw UnimplementedError('scopeSourceProvider must be overridden'),
);
