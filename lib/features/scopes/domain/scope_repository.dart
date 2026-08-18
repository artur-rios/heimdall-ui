import '../../../core/network/envelope.dart';
import '../../../core/result/result.dart';
import 'scope.dart';

/// The scope operations the interface depends on.
///
/// Implemented in `features/scopes/data` over the generated client, and faked
/// in tests — which is why nothing here mentions a transport.
abstract interface class ScopeRepository {
  /// Reads one page of scopes.
  ///
  /// The API decides what the caller may see: a System Admin gets every scope,
  /// a Scope Admin only the ones they own (AF-10c). Nothing here filters by
  /// ownership, because the interface is not the authority on that.
  Future<Result<Page<Scope>>> list({
    String? name,
    bool includeDeleted = false,
    int pageNumber = 1,
    int pageSize = 20,
  });
}
