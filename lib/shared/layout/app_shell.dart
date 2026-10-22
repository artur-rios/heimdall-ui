import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme_mode_controller.dart';
import '../../features/auth/domain/session.dart';
import '../../features/auth/presentation/session_controller.dart';
import '../../features/auth/presentation/verification_banner.dart';
import '../../features/home/presentation/destinations.dart';
import '../forms/edit_mode.dart';
import '../forms/unsaved_changes.dart';
import '../widgets/page_title.dart';
import 'adaptive_scaffold.dart';

/// The frame every signed-in screen sits in: the navigation for the role, the
/// theme control, sign-out, and the unverified-address prompt.
///
/// Screens hand it a [body] and a [currentRoute] and think about nothing else,
/// which is what keeps one shell decision in one place rather than one per
/// screen.
class AppShell extends ConsumerWidget {
  const AppShell({
    required this.currentRoute,
    required this.title,
    required this.body,
    this.actions = const <Widget>[],
    this.floatingActionButton,
    this.backRoute,
    this.onBack,
    this.backTooltip = 'Back',
    this.confirmLeave,
    this.hasUnsavedChanges,
    this.onReturn,
    super.key,
  });

  /// The destination route this screen belongs to, which decides what the
  /// navigation shows as selected. A screen below a destination — a detail
  /// under a listing — passes the destination's own route.
  final String currentRoute;

  /// The screen's name. When it is a plain [Text] it also names the browser
  /// tab (`<name> - Heimdall`), so every shell screen is titled from this one
  /// place.
  final Widget title;
  final Widget body;
  final List<Widget> actions;
  final Widget? floatingActionButton;

  /// Where the back control leading the title goes, on a screen below a
  /// destination. Without it, or [onBack], the screen has no back control:
  /// the navigation is the way out of a destination.
  final String? backRoute;

  /// What the back control does when leaving needs more than a route — a
  /// screen that must first ask whether to abandon something, say. Wins over
  /// [backRoute].
  final VoidCallback? onBack;

  final String backTooltip;

  /// Asked before the navigation, the [backRoute] control or signing out
  /// takes the person off this screen; `false` keeps them here. Only for what
  /// is not an edit and is not left like one: freshly issued recovery codes,
  /// whose leaving signs the person out. An unsaved edit or form is
  /// [hasUnsavedChanges]'s, asked by the route. An [onBack] callback asks for
  /// itself.
  final Future<bool> Function()? confirmLeave;

  /// Whether this screen holds an edit that is not yet saved.
  ///
  /// The route asks "Discard your changes?" before the screen is left with
  /// one, through its `onExit` ([confirmLeaveWithUnsavedChanges]), so the
  /// navigation, the back control, a system Back and a browser Back are all
  /// covered by the one question. Signing out is no route change the screen
  /// can refuse, so the shell asks before it.
  final bool Function()? hasUnsavedChanges;

  /// Called when this screen is on top again after a screen opened over it is
  /// left — a listing back from a record, say.
  ///
  /// Routes nest, so the screen underneath stays as it was while the one over
  /// it changed or deleted what it shows; this is where it reads it again.
  final VoidCallback? onReturn;

  Future<bool> _mayLeave() async => await confirmLeave?.call() ?? true;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);

    if (session is! Authenticated) {
      // The guard is already redirecting; this is what the frame in between
      // shows rather than a half-built shell.
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final destinations = destinationsFor(session.principal);
    final selected = destinations.indexWhere(
      (destination) => destination.route == currentRoute,
    );

    final scaffold = AdaptiveScaffold(
      destinations: destinations,
      // A screen that is not itself a destination still has to select
      // something; the first entry is what the navigation highlights.
      selectedIndex: selected < 0 ? 0 : selected,
      onDestinationSelected: (index) async {
        if (await _mayLeave() && context.mounted) {
          context.go(destinations[index].route);
        }
      },
      title: title,
      leading: _backControl(context),
      floatingActionButton: floatingActionButton,
      actions: <Widget>[
        ...actions,
        const ThemeModeAction(),
        IconButton(
          tooltip: 'Sign out',
          icon: const Icon(Icons.logout),
          onPressed: () async {
            // Every screen with an edit is asked about, not only this one: a
            // record being edited may sit under the screen on top.
            if (await _mayLeave() &&
                context.mounted &&
                await confirmDiscardChanges(
                  context,
                  hasChanges: ref.read(unsavedChangesProvider).any,
                )) {
              await ref.read(sessionControllerProvider.notifier).signOut();
            }
          },
        ),
      ],
      body: Column(
        children: <Widget>[
          // AF-05e: renders nothing when the address is verified or the prompt
          // was dismissed, so it sits here unconditionally.
          const VerificationBanner(),
          Expanded(child: body),
        ],
      ),
    );

    final Widget screen = switch (title) {
      Text(data: final name?) => PageTitle(title: name, child: scaffold),
      _ => scaffold,
    };

    if (hasUnsavedChanges == null && onReturn == null) {
      return screen;
    }

    return _RouteBindings(
      hasUnsavedChanges: hasUnsavedChanges,
      onReturn: onReturn,
      child: screen,
    );
  }

  Widget? _backControl(BuildContext context) {
    final route = backRoute;
    final action =
        onBack ??
        (route == null
            ? null
            : () async {
                if (await _mayLeave() && context.mounted) {
                  context.go(route);
                }
              });

    if (action == null) {
      return null;
    }

    return IconButton(
      tooltip: backTooltip,
      icon: const Icon(Icons.arrow_back),
      onPressed: action,
    );
  }
}

/// Ties a screen to the route that built it: registers its unsaved-changes
/// question for the route's `onExit`, and tells it when it is back on top.
///
/// Inert outside a `GoRouter`, where there is no route to tie it to.
class _RouteBindings extends ConsumerStatefulWidget {
  const _RouteBindings({
    required this.hasUnsavedChanges,
    required this.onReturn,
    required this.child,
  });

  final bool Function()? hasUnsavedChanges;
  final VoidCallback? onReturn;
  final Widget child;

  @override
  ConsumerState<_RouteBindings> createState() => _RouteBindingsState();
}

class _RouteBindingsState extends ConsumerState<_RouteBindings> {
  UnsavedChanges? _registry;
  GoRouterDelegate? _delegate;
  LocalKey? _page;

  /// Whether this screen's page was the top one at the last route change.
  bool _onTop = true;

  /// Reads the current callback, so the registration made once keeps
  /// answering for the screen as it rebuilds.
  bool _hasUnsavedChanges() => widget.hasUnsavedChanges?.call() ?? false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_page != null) {
      return;
    }

    final router = GoRouter.maybeOf(context);

    if (router == null) {
      return;
    }

    final page = GoRouterState.of(context).pageKey;
    final registry = ref.read(unsavedChangesProvider)
      ..register(page, _hasUnsavedChanges);
    final delegate = router.routerDelegate..addListener(_routeChanged);
    _page = page;
    _registry = registry;
    _delegate = delegate;
    _onTop = _isOnTop();
  }

  bool _isOnTop() {
    final configuration = _delegate?.currentConfiguration;

    return configuration != null &&
        configuration.isNotEmpty &&
        configuration.last.pageKey == _page;
  }

  void _routeChanged() {
    final onTop = _isOnTop();

    if (onTop && !_onTop) {
      // The route changes mid-frame; the screen reads again after it.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.onReturn?.call();
        }
      });
    }

    _onTop = onTop;
  }

  @override
  void dispose() {
    _delegate?.removeListener(_routeChanged);

    if (_page case final page?) {
      _registry?.unregister(page, _hasUnsavedChanges);
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Cycles system → light → dark, and shows which is active.
class ThemeModeAction extends ConsumerWidget {
  const ThemeModeAction({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode =
        ref.watch(themeModeControllerProvider).value ?? ThemeMode.system;

    return IconButton(
      tooltip: switch (mode) {
        ThemeMode.system => 'Theme: follow the system',
        ThemeMode.light => 'Theme: light',
        ThemeMode.dark => 'Theme: dark',
      },
      icon: Icon(switch (mode) {
        ThemeMode.system => Icons.brightness_auto_outlined,
        ThemeMode.light => Icons.light_mode_outlined,
        ThemeMode.dark => Icons.dark_mode_outlined,
      }),
      onPressed: () =>
          ref.read(themeModeControllerProvider.notifier).setMode(switch (mode) {
            ThemeMode.system => ThemeMode.light,
            ThemeMode.light => ThemeMode.dark,
            ThemeMode.dark => ThemeMode.system,
          }),
    );
  }
}
