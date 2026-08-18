import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/applications/presentation/application_create_screen.dart';
import '../features/applications/presentation/application_detail_screen.dart';
import '../features/applications/presentation/application_list_screen.dart';
import '../features/auth/domain/session.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/password_recovery_screen.dart';
import '../features/auth/presentation/password_reset_screen.dart';
import '../features/auth/presentation/session_controller.dart';
import '../features/auth/presentation/two_factor_screen.dart';
import '../features/auth/presentation/verify_email_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/permissions/presentation/permission_create_screen.dart';
import '../features/permissions/presentation/permission_detail_screen.dart';
import '../features/permissions/presentation/permission_list_screen.dart';
import '../features/persons/presentation/person_create_screen.dart';
import '../features/persons/presentation/person_detail_screen.dart';
import '../features/persons/presentation/person_list_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/scopes/presentation/scope_create_screen.dart';
import '../features/scopes/presentation/scope_detail_screen.dart';
import '../features/scopes/presentation/scope_list_screen.dart';
import '../features/scopes/presentation/scope_owners_screen.dart';
import 'route_access.dart';

/// Routes an unauthenticated caller may reach.
///
/// The recovery, reset, and verification screens are here because they are all
/// opened from an emailed link by someone who, by definition, cannot sign in.
const Set<String> publicRoutes = <String>{
  '/login',
  '/login/two-factor',
  '/password-recovery',
  '/password-reset',
  '/verify-email',
};

/// Decides where a caller in [session] asking for [location] should end up, or
/// `null` when they may stay.
///
/// Pure on purpose: the whole guard is then testable without a widget tree,
/// which is where its edge cases actually live.
String? redirectFor({required SessionState session, required String location}) {
  final uri = Uri.parse(location);
  final path = uri.path;
  final isPublic = publicRoutes.contains(path);

  return switch (session) {
    // Say nothing until the stored token has been read, so a slow read cannot
    // bounce a returning user to sign-in.
    SessionRestoring() => null,
    Challenged() => path == '/login/two-factor' ? null : '/login/two-factor',
    // AF-02b and AF-02e: a challenge screen without a challenge is a dead end.
    // The token is gone and cannot be recovered, so sign-in restarts.
    Unauthenticated() when path == '/login/two-factor' => '/login',
    Unauthenticated() when isPublic => null,
    Unauthenticated() => '/login?from=${Uri.encodeComponent(location)}',
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
    ),
    routes: <RouteBase>[
      GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
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
        // what is wrong. Refusing to route would only show "not found".
        builder: (context, state) =>
            PasswordResetScreen(token: state.uri.queryParameters['token']),
      ),
      GoRoute(
        path: '/verify-email',
        // AF-05a: as with the reset link, a link without `token` still reaches
        // the screen, which explains and offers the resend.
        builder: (context, state) =>
            VerifyEmailScreen(token: state.uri.queryParameters['token']),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/scopes',
        builder: (context, state) => const ScopeListScreen(),
      ),
      GoRoute(
        path: '/scopes/new',
        builder: (context, state) => const ScopeCreateScreen(),
      ),
      GoRoute(
        path: '/scopes/:scopeId',
        builder: (context, state) =>
            ScopeDetailScreen(scopeId: state.pathParameters['scopeId']!),
      ),
      GoRoute(
        path: '/scopes/:scopeId/applications',
        builder: (context, state) =>
            ApplicationListScreen(scopeId: state.pathParameters['scopeId']!),
      ),
      GoRoute(
        path: '/scopes/:scopeId/applications/new',
        builder: (context, state) =>
            ApplicationCreateScreen(scopeId: state.pathParameters['scopeId']!),
      ),
      GoRoute(
        path: '/scopes/:scopeId/applications/:applicationId',
        builder: (context, state) => ApplicationDetailScreen(
          scopeId: state.pathParameters['scopeId']!,
          applicationId: state.pathParameters['applicationId']!,
        ),
      ),
      GoRoute(
        path: '/scopes/:scopeId/permissions',
        builder: (context, state) =>
            PermissionListScreen(scopeId: state.pathParameters['scopeId']!),
      ),
      GoRoute(
        path: '/scopes/:scopeId/permissions/new',
        builder: (context, state) =>
            PermissionCreateScreen(scopeId: state.pathParameters['scopeId']!),
      ),
      GoRoute(
        path: '/scopes/:scopeId/permissions/:permissionId',
        builder: (context, state) => PermissionDetailScreen(
          scopeId: state.pathParameters['scopeId']!,
          permissionId: state.pathParameters['permissionId']!,
        ),
      ),
      GoRoute(
        path: '/scopes/:scopeId/owners',
        builder: (context, state) =>
            ScopeOwnersScreen(scopeId: state.pathParameters['scopeId']!),
      ),
      GoRoute(
        path: '/scopes/:scopeId/persons',
        builder: (context, state) =>
            PersonListScreen(scopeId: state.pathParameters['scopeId']!),
      ),
      GoRoute(
        path: '/scopes/:scopeId/persons/new',
        builder: (context, state) =>
            PersonCreateScreen(scopeId: state.pathParameters['scopeId']!),
      ),
      GoRoute(
        path: '/scopes/:scopeId/persons/:personId',
        builder: (context, state) => PersonDetailScreen(
          scopeId: state.pathParameters['scopeId']!,
          personId: state.pathParameters['personId']!,
        ),
      ),
      GoRoute(
        path: '/not-available',
        builder: (context, state) => const _NotForYourRoleScreen(),
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

    return Scaffold(
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
    );
  }
}

class _RouteNotReadyScreen extends StatelessWidget {
  const _RouteNotReadyScreen({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: IconButton(
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
