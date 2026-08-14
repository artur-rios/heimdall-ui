import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/domain/session.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/session_controller.dart';
import '../features/home/presentation/home_screen.dart';

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
    Unauthenticated() when isPublic => null,
    Unauthenticated() => '/login?from=${Uri.encodeComponent(location)}',
    Authenticated() when path == '/login' || path == '/login/two-factor' =>
      _returnTo(uri.queryParameters['from']),
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
    ],
    // Every screen beyond these two arrives with its own use case. Until then
    // an unknown route says so plainly instead of throwing.
    errorBuilder: (context, state) =>
        _RouteNotReadyScreen(path: state.uri.path),
  );
});

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
