import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:heimdall_api_client/export.dart';

import 'app/heimdall_app.dart';
import 'app/startup_guard.dart';
import 'core/config/app_config.dart';
import 'core/entry/entry_link.dart';
import 'core/entry/platform_entry_link.dart';
import 'core/network/dio_client.dart';
import 'core/scope/scope_source.dart';
import 'core/scope/session_scope_source.dart';
import 'core/storage/token_store.dart';
import 'features/applications/data/application_credential_repository_impl.dart';
import 'features/applications/data/application_repository_impl.dart';
import 'features/applications/domain/application_credential_repository.dart';
import 'features/applications/domain/application_repository.dart';
import 'features/audit_log/data/audit_log_repository_impl.dart';
import 'features/audit_log/domain/audit_log_repository.dart';
import 'features/auth/data/auth_repository_impl.dart';
import 'features/auth/data/google_sign_in_gateway_impl.dart';
import 'features/auth/presentation/session_controller.dart';
import 'features/data_rights/data/data_rights_repository_impl.dart';
import 'features/data_rights/domain/data_rights_repository.dart';
import 'features/erasure_requests/data/erasure_request_repository_impl.dart';
import 'features/erasure_requests/domain/erasure_request_repository.dart';
import 'features/google_users/data/google_user_repository_impl.dart';
import 'features/google_users/domain/google_user_repository.dart';
import 'features/health/data/health_repository_impl.dart';
import 'features/health/domain/health_repository.dart';
import 'features/permissions/data/scope_permission_repository_impl.dart';
import 'features/permissions/domain/scope_permission_repository.dart';
import 'features/persons/data/person_repository_impl.dart';
import 'features/profile/presentation/profile_controller.dart';
import 'features/scope_invitations/data/scope_invitation_repository_impl.dart';
import 'features/scope_invitations/domain/scope_invitation_repository.dart';
import 'features/scopes/data/pending_registration_repository_impl.dart';
import 'features/scopes/data/scope_repository_impl.dart';
import 'features/scopes/domain/pending_registration_repository.dart';
import 'features/scopes/presentation/scope_list_controller.dart';

void main() {
  // Before anything reads the address: the scope a caller handed over and a
  // reset or verification token are taken out of it, so the router starts
  // from the address without them and no history entry keeps them. A no-op
  // off the web.
  final entry = takePlatformEntryLink();

  // Route on the path, not the fragment. The API e-mails links such as
  // `/password-reset?token=…`; under Flutter's default hash strategy those
  // resolve to `/` and the guard sends the caller to sign-in, token and all.
  // First, because the engine refuses a strategy once it has initialised; a
  // no-op off the web.
  usePathUrlStrategy();
  WidgetsFlutterBinding.ensureInitialized();

  final config = AppConfig.fromEnvironment();

  // A release of the installed apps refuses a cleartext API before anything
  // is sent to it, and says why on screen as well as in the log.
  runApp(
    guardStartup(
      config,
      () => ProviderScope(
        // Riverpod 3 retries a failing provider on its own. This app reports
        // failures as values and leaves retrying to the user (FR-UX-07), so a
        // provider that throws fails once, as it did under Riverpod 2.
        retry: (retryCount, error) => null,
        overrides: <Override>[
          appConfigProvider.overrideWithValue(config),
          entryLinkProvider.overrideWith(() => EntryLinkController(entry)),
          tokenStoreProvider.overrideWithValue(
            const SecureTokenStore.platform(),
          ),
          // The scope belongs to whichever application sent the user here;
          // on the web it is read from session storage on every use (where
          // start-up put a `?scope=` the caller handed over), so a caller may
          // change it between one attempt and the next.
          scopeSourceProvider.overrideWithValue(
            sessionScopeSource(fallback: config.scopeId),
          ),
          authRepositoryProvider.overrideWith(
            (ref) => ApiAuthRepository(AuthClient(ref.watch(dioProvider))),
          ),
          dataRightsRepositoryProvider.overrideWith(
            (ref) =>
                ApiDataRightsRepository(AuthClient(ref.watch(dioProvider))),
          ),
          erasureRequestRepositoryProvider.overrideWith(
            (ref) =>
                ApiErasureRequestRepository(AuthClient(ref.watch(dioProvider))),
          ),
          auditLogRepositoryProvider.overrideWith(
            (ref) => ApiAuditLogRepository(AuditClient(ref.watch(dioProvider))),
          ),
          personRepositoryProvider.overrideWith(
            (ref) => ApiPersonRepository(PersonClient(ref.watch(dioProvider))),
          ),
          applicationRepositoryProvider.overrideWith(
            (ref) => ApiApplicationRepository(
              ApplicationClient(ref.watch(dioProvider)),
            ),
          ),
          applicationCredentialRepositoryProvider.overrideWith(
            (ref) => ApiApplicationCredentialRepository(
              ApplicationCredentialClient(ref.watch(dioProvider)),
            ),
          ),
          googleUserRepositoryProvider.overrideWith(
            (ref) => ApiGoogleUserRepository(
              GoogleUserClient(ref.watch(dioProvider)),
            ),
          ),
          healthRepositoryProvider.overrideWith(
            (ref) =>
                ApiHealthRepository(HealthCheckClient(ref.watch(dioProvider))),
          ),
          scopePermissionRepositoryProvider.overrideWith(
            (ref) => ApiScopePermissionRepository(
              ScopePermissionClient(ref.watch(dioProvider)),
            ),
          ),
          scopeRepositoryProvider.overrideWith(
            (ref) => ApiScopeRepository(ScopeClient(ref.watch(dioProvider))),
          ),
          pendingRegistrationRepositoryProvider.overrideWith(
            (ref) => ApiPendingRegistrationRepository(
              ScopeClient(ref.watch(dioProvider)),
            ),
          ),
          scopeInvitationRepositoryProvider.overrideWith(
            (ref) => ApiScopeInvitationRepository(
              ScopeInvitationClient(ref.watch(dioProvider)),
            ),
          ),
          googleSignInGatewayProvider.overrideWithValue(
            PluginGoogleSignInGateway(
              GoogleSignIn.instance,
              config.googleClientId,
            ),
          ),
        ],
        child: const HeimdallApp(),
      ),
    ),
  );
}
