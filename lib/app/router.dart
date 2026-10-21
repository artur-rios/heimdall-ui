import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/entry/entry_link.dart';
import '../core/ids/public_id.dart';
import '../features/applications/presentation/application_create_screen.dart';
import '../features/applications/presentation/application_detail_screen.dart';
import '../features/applications/presentation/application_list_screen.dart';
import '../features/applications/presentation/pending_secret.dart';
import '../features/auth/domain/session.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/password_recovery_screen.dart';
import '../features/auth/presentation/password_reset_screen.dart';
import '../features/auth/presentation/session_controller.dart';
import '../features/auth/presentation/two_factor_screen.dart';
import '../features/auth/presentation/verify_email_screen.dart';
import '../features/data_rights/presentation/restricted_session_screen.dart';
import '../features/audit_log/presentation/audit_log_screen.dart';
import '../features/erasure_requests/presentation/erasure_request_list_screen.dart';
import '../features/health/presentation/health_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/google_users/presentation/google_user_detail_screen.dart';
import '../features/google_users/presentation/google_user_list_screen.dart';
import '../features/permissions/presentation/permission_create_screen.dart';
import '../features/permissions/presentation/permission_detail_screen.dart';
import '../features/permissions/presentation/permission_list_screen.dart';
import '../features/persons/presentation/person_create_screen.dart';
import '../features/persons/presentation/person_detail_screen.dart';
import '../features/persons/presentation/person_list_screen.dart';
import '../features/persons/presentation/system_admin_list_screen.dart';
import '../features/privacy/presentation/privacy_notice_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/profile/presentation/security_screen.dart';
import '../features/scopes/presentation/pending_registration_list_screen.dart';
import '../features/scopes/presentation/scope_create_screen.dart';
import '../features/scopes/presentation/scope_detail_screen.dart';
import '../features/scopes/presentation/scope_list_screen.dart';
import '../features/scopes/presentation/scope_owners_screen.dart';
import '../features/scopes/presentation/scope_sign_in_settings_screen.dart';
import '../shared/forms/unsaved_changes.dart';
import '../shared/widgets/page_title.dart';
import 'route_access.dart';

/// Where a link that names no record lands: one whose id is not a `PublicId`.
const String notFoundRoute = '/not-found';

/// Routes an unauthenticated caller may reach.
///
/// The recovery, reset, and verification screens are here because they are all
/// opened from an emailed link by someone who, by definition, cannot sign in.
/// The privacy notice is here because Google's consent screen links to it, and
/// the person reading it there has not signed in yet. The not-found screen is
/// here because a link to nothing is that whoever follows it.
const Set<String> publicRoutes = <String>{
  notFoundRoute,
  '/login',
  '/login/two-factor',
  '/password-recovery',
  '/password-reset',
  '/verify-email',
  '/privacy',
};

/// The one screen a restricted session (UI-30) is given.
const String restrictedRoute = '/restricted';

/// What a restricted session may reach besides [restrictedRoute]: the public
/// pages that are of use to a signed-in person. The privacy notice is the one
/// that matters here — it says what the rights on that screen are.
const Set<String> _restrictedSessionPublicRoutes = <String>{'/privacy'};

/// Decides where a caller in [session] asking for [location] should end up, or
/// `null` when they may stay.
///
/// [pathParameters] are the route's decoded parameters. Every one of them is a
/// record's id, and an id that is not a `PublicId` sends the caller to
/// [notFoundRoute] before any screen is built with it: go_router decodes a
/// segment such as `..%2F..%2Fpersons%2F<id>`, and a screen handed that would
/// load, and offer to delete, a record other than the one its link named.
///
/// Pure on purpose: the whole guard is then testable without a widget tree,
/// which is where its edge cases actually live.
String? redirectFor({
  required SessionState session,
  required String location,
  Map<String, String> pathParameters = const <String, String>{},
}) {
  // First, whatever the session: a link to nothing stays one after signing in,
  // and the not-found screen is public, so this cannot loop.
  if (pathParameters.values.any((id) => !isPublicId(id))) {
    return notFoundRoute;
  }

  final uri = Uri.parse(location);
  final path = uri.path;
  final isPublic = publicRoutes.contains(path);

  return switch (session) {
    // Say nothing until the stored token has been read, so a slow read cannot
    // bounce a returning user to sign-in.
    SessionRestoring() => null,
    // The deep link rides along, since the second factor is a detour on the
    // way to it (AF-07a), not the end of the sign-in.
    Challenged() when path == '/login/two-factor' => null,
    Challenged() => switch (uri.queryParameters['from']) {
      final String from when path == '/login' =>
        '/login/two-factor?from=${Uri.encodeComponent(from)}',
      _ => '/login/two-factor',
    },
    // AF-02b and AF-02e: a challenge screen without a challenge is a dead end.
    // The token is gone and cannot be recovered, so sign-in restarts.
    Unauthenticated() when path == '/login/two-factor' => '/login',
    Unauthenticated() when isPublic => null,
    Unauthenticated() => '/login?from=${Uri.encodeComponent(location)}',
    // UI-30: a subject-rights-only token is refused everywhere but the rights
    // endpoints, whatever its role, so every other screen would only fail.
    // Ahead of the sign-in redirect, which would otherwise send a person who
    // has just signed in somewhere they cannot use; and the screen it sends
    // them to is let through, so this cannot loop.
    Authenticated(:final principal) when principal.subjectRightsOnly =>
      path == restrictedRoute || _restrictedSessionPublicRoutes.contains(path)
          ? null
          : restrictedRoute,
    // A full session has nothing to do on the restricted screen: lifting a
    // restriction it does not have would only be refused.
    Authenticated() when path == restrictedRoute => '/',
    Authenticated() when path == '/login' || path == '/login/two-factor' =>
      _returnTo(uri.queryParameters['from']),
    // AF-07d: a screen this role is not offered answers plainly. Sending them
    // home instead would be the redirect loop the flow rules out, and would
    // also lie about why they did not arrive.
    Authenticated(:final principal)
        when !isPublic && !roleMayReach(role: principal.role, path: path) =>
      '/not-available',
    Authenticated() => null,
  };
}

/// Where a freshly signed-in caller belongs: the screen they originally asked
/// for, or the home screen.
///
/// Only a path within this application is honoured. A value that is absolute,
/// protocol-relative, or a login route itself would either send the user off
/// the application or straight back into the sign-in loop, so both fall back
/// home rather than being followed.
String _returnTo(String? from) {
  if (from == null || !from.startsWith('/') || from.startsWith('//')) {
    return '/';
  }

  final path = Uri.parse(from).path;

  return (path == '/login' || path == '/login/two-factor') ? '/' : from;
}

final Provider<GoRouter> routerProvider = Provider<GoRouter>((ref) {
  final listenable = _SessionListenable(ref);
  ref.onDispose(listenable.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: listenable,
    redirect: (context, state) => redirectFor(
      session: ref.read(sessionControllerProvider),
      location: state.uri.toString(),
      pathParameters: state.pathParameters,
    ),
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (context, state) => const HomeScreen(),
        // The System Admins listing is opened from Home, so Back returns
        // there; its person pages sit under it.
        routes: <RouteBase>[
          GoRoute(
            path: 'system-admins',
            builder: (context, state) => const SystemAdminListScreen(),
            routes: <RouteBase>[
              GoRoute(
                path: ':personId',
                builder: (context, state) => PersonDetailScreen(
                  personId: state.pathParameters['personId']!,
                ),
                onExit: confirmLeaveWithUnsavedChanges,
              ),
            ],
          ),
        ],
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/login/two-factor',
        builder: (context, state) => const TwoFactorScreen(),
      ),
      GoRoute(
        path: '/password-recovery',
        builder: (context, state) => const PasswordRecoveryScreen(),
      ),
      GoRoute(
        path: '/password-reset',
        // AF-04a: a link without `token` still reaches the screen, which says
        // what is wrong. Refusing to route would only show "not found". On the
        // web start-up has already taken the token out of the address.
        builder: (context, state) => PasswordResetScreen(
          token:
              state.uri.queryParameters['token'] ??
              ref.read(entryLinkProvider).resetToken,
        ),
      ),
      GoRoute(
        path: '/verify-email',
        // AF-05a: as with the reset link, a link without `token` still reaches
        // the screen, which explains and offers the resend.
        builder: (context, state) => VerifyEmailScreen(
          token:
              state.uri.queryParameters['token'] ??
              ref.read(entryLinkProvider).verificationToken,
        ),
      ),
      GoRoute(
        path: '/privacy',
        builder: (context, state) => const PrivacyNoticeScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
        onExit: confirmLeaveWithUnsavedChanges,
        // Security is opened from the profile, so Back returns there.
        routes: <RouteBase>[
          GoRoute(
            path: 'security',
            builder: (context, state) => const SecurityScreen(),
            // UI-09 AF-09c — recovery codes not yet acknowledged are lost by
            // leaving, and leaving them signs the person out.
            onExit: (context, state) =>
                confirmLeaveWithRecoveryCodes(context, ref),
          ),
        ],
      ),
      // A record's route is nested under its listing's, and a scope's own
      // screens under the scope's, so the pages below a screen are the ones it
      // was opened from. A system or browser Back then returns to them, and a
      // deep link arrives with them already underneath.
      GoRoute(
        path: '/scopes',
        builder: (context, state) => const ScopeListScreen(),
        routes: <RouteBase>[
          GoRoute(
            path: 'new',
            builder: (context, state) => const ScopeCreateScreen(),
            onExit: confirmLeaveWithUnsavedChanges,
          ),
          GoRoute(
            path: ':scopeId',
            builder: (context, state) =>
                ScopeDetailScreen(scopeId: state.pathParameters['scopeId']!),
            onExit: confirmLeaveWithUnsavedChanges,
            routes: <RouteBase>[
              GoRoute(
                path: 'applications',
                builder: (context, state) => ApplicationListScreen(
                  scopeId: state.pathParameters['scopeId']!,
                ),
                routes: <RouteBase>[
                  GoRoute(
                    path: 'new',
                    builder: (context, state) => ApplicationCreateScreen(
                      scopeId: state.pathParameters['scopeId']!,
                    ),
                    onExit: confirmLeaveWithUnsavedChanges,
                  ),
                  GoRoute(
                    path: ':applicationId',
                    builder: (context, state) => ApplicationDetailScreen(
                      scopeId: state.pathParameters['scopeId']!,
                      applicationId: state.pathParameters['applicationId']!,
                    ),
                    // UI-37 — a one-time secret not yet stored is lost by
                    // leaving, and so is an unsaved edit.
                    onExit: (context, state) async =>
                        await confirmLeaveWithPendingSecret(context, ref) &&
                        context.mounted &&
                        await confirmLeaveWithUnsavedChanges(context, state),
                  ),
                ],
              ),
              GoRoute(
                path: 'permissions',
                builder: (context, state) => PermissionListScreen(
                  scopeId: state.pathParameters['scopeId']!,
                ),
                routes: <RouteBase>[
                  GoRoute(
                    path: 'new',
                    builder: (context, state) => PermissionCreateScreen(
                      scopeId: state.pathParameters['scopeId']!,
                    ),
                    onExit: confirmLeaveWithUnsavedChanges,
                  ),
                  GoRoute(
                    path: ':permissionId',
                    builder: (context, state) => PermissionDetailScreen(
                      scopeId: state.pathParameters['scopeId']!,
                      permissionId: state.pathParameters['permissionId']!,
                    ),
                    onExit: confirmLeaveWithUnsavedChanges,
                  ),
                ],
              ),
              GoRoute(
                path: 'google-users',
                builder: (context, state) => GoogleUserListScreen(
                  scopeId: state.pathParameters['scopeId']!,
                ),
                routes: <RouteBase>[
                  GoRoute(
                    path: ':googleUserId',
                    builder: (context, state) => GoogleUserDetailScreen(
                      scopeId: state.pathParameters['scopeId']!,
                      googleUserId: state.pathParameters['googleUserId']!,
                    ),
                  ),
                ],
              ),
              GoRoute(
                path: 'owners',
                builder: (context, state) => ScopeOwnersScreen(
                  scopeId: state.pathParameters['scopeId']!,
                ),
              ),
              GoRoute(
                path: 'sign-in-settings',
                builder: (context, state) => ScopeSignInSettingsScreen(
                  scopeId: state.pathParameters['scopeId']!,
                ),
                onExit: confirmLeaveWithUnsavedChanges,
              ),
              GoRoute(
                path: 'pending-registrations',
                builder: (context, state) => PendingRegistrationListScreen(
                  scopeId: state.pathParameters['scopeId']!,
                ),
              ),
              GoRoute(
                path: 'persons',
                builder: (context, state) =>
                    PersonListScreen(scopeId: state.pathParameters['scopeId']!),
                routes: <RouteBase>[
                  GoRoute(
                    path: 'new',
                    builder: (context, state) => PersonCreateScreen(
                      scopeId: state.pathParameters['scopeId']!,
                    ),
                    onExit: confirmLeaveWithUnsavedChanges,
                  ),
                  GoRoute(
                    path: ':personId',
                    builder: (context, state) => PersonDetailScreen(
                      scopeId: state.pathParameters['scopeId']!,
                      personId: state.pathParameters['personId']!,
                    ),
                    onExit: confirmLeaveWithUnsavedChanges,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      // The person page without a scope moved under the listing it is opened
      // from; a link to its earlier address still arrives there.
      GoRoute(
        path: '/persons/:personId',
        redirect: (context, state) =>
            '/system-admins/${state.pathParameters['personId']}',
      ),
      GoRoute(
        path: '/erasure-requests',
        builder: (context, state) => const ErasureRequestListScreen(),
      ),
      GoRoute(
        path: '/audit-log',
        builder: (context, state) => const AuditLogScreen(),
      ),
      GoRoute(
        path: '/health',
        builder: (context, state) => const HealthScreen(),
      ),
      GoRoute(
        path: restrictedRoute,
        builder: (context, state) => const RestrictedSessionScreen(),
      ),
      GoRoute(
        path: '/not-available',
        builder: (context, state) => const _NotForYourRoleScreen(),
      ),
      GoRoute(
        path: notFoundRoute,
        builder: (context, state) => const _NotFoundScreen(),
      ),
    ],
    // Every screen beyond these two arrives with its own use case. Until then
    // an unknown route says so plainly instead of throwing.
    errorBuilder: (context, state) =>
        _RouteNotReadyScreen(path: state.uri.path),
  );
});

/// AF-07d — what a caller sees when their role is not offered the screen they
/// asked for.
///
/// A screen rather than a redirect: it says what happened, and it cannot loop.
class _NotForYourRoleScreen extends StatelessWidget {
  const _NotForYourRoleScreen();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PageTitle(
      title: 'Not available',
      child: Scaffold(
        appBar: AppBar(title: const Text('Not available')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    Icons.lock_person_outlined,
                    size: 48,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Not available for your role',
                    style: theme.textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your account is signed in, but this screen is not part of '
                    'what your role does. Nothing is wrong with your session.',
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () => context.go('/'),
                    child: const Text('Back to home'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// What a link whose id is not a `PublicId` opens: nothing, said plainly.
///
/// The id itself is not repeated: it is whatever the link carried, and the
/// screen has no business echoing it.
class _NotFoundScreen extends StatelessWidget {
  const _NotFoundScreen();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PageTitle(
      title: 'Not found',
      child: Scaffold(
        appBar: AppBar(title: const Text('Not found')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    Icons.link_off,
                    size: 48,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Nothing at this address',
                    style: theme.textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'The link is incomplete or was changed, so it names no '
                    'record. Nothing was opened.',
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () => context.go('/'),
                    child: const Text('Back to home'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RouteNotReadyScreen extends StatelessWidget {
  const _RouteNotReadyScreen({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) => PageTitle(
    title: 'Not available yet',
    child: Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back to home',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        title: const Text('Not available yet'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            '$path has not been built yet.',
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    ),
  );
}

/// Re-runs the redirect whenever the session changes, which is what moves the
/// user off the sign-in screen the moment a session exists.
class _SessionListenable extends ChangeNotifier {
  _SessionListenable(Ref ref) {
    ref.listen<SessionState>(
      sessionControllerProvider,
      (previous, next) => notifyListeners(),
    );
  }
}
