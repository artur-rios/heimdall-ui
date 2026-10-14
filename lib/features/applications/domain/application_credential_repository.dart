import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/result/result.dart';
import 'application_credential.dart';

/// The credential operations UI-37 depends on. System Admin or the owning
/// Scope Admin; the API refuses anybody else.
abstract interface class ApplicationCredentialRepository {
  /// The application's credentials, newest first (UC-54). Never a secret.
  Future<Result<List<ApplicationCredential>>> list(
    String scopeId,
    String applicationId,
  );

  /// Issues a credential (UC-53), optionally expiring at [expiresAt]. The
  /// answer carries the secret, the only time it is ever available. A `409`
  /// means the application already has two live credentials (AF-37b).
  Future<Result<IssuedCredential>> issue(
    String scopeId,
    String applicationId, {
    DateTime? expiresAt,
  });

  /// Revokes one credential (UC-55); its secret stops working at once.
  Future<Result<void>> revoke(
    String scopeId,
    String applicationId,
    String credentialId,
  );
}

/// Overridden at start-up with the client-backed implementation, and in tests
/// with a fake.
final Provider<ApplicationCredentialRepository>
applicationCredentialRepositoryProvider =
    Provider<ApplicationCredentialRepository>(
      (ref) => throw UnimplementedError(
        'applicationCredentialRepositoryProvider must be overridden',
      ),
    );
