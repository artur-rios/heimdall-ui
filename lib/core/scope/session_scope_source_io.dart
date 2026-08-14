import 'scope_source.dart';

/// The non-web targets have no calling application to read a scope from, so the
/// build-time value is the whole answer.
ScopeSource sessionScopeSource({String? fallback}) =>
    FixedScopeSource(fallback);
