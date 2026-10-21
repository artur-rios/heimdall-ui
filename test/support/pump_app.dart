import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:heimdall_ui/app/theme.dart';
import 'package:heimdall_ui/core/storage/token_store.dart';
import 'package:heimdall_ui/features/auth/presentation/session_controller.dart';
import 'package:heimdall_ui/shared/widgets/page_title.dart';

import 'idle_expiry_timer.dart';

/// The three window classes the shell lays out differently.
const Size compactWindow = Size(400, 900);
const Size mediumWindow = Size(800, 900);
const Size expandedWindow = Size(1400, 900);

/// Gives the test a window of [size] at a pixel ratio of 1, put back when the
/// test ends.
void useWindow(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// A container with the session's expiry timer made idle, for a test that
/// builds its own: a real timer would be left pending on a widget test's fake
/// clock. Pass `sessionExpiryTimerProvider` in [overrides] to test the expiry
/// itself; [overrides] come after the harness's own and win. The session is
/// not restored. The container is disposed with the test.
ProviderContainer testContainer({
  TokenStore? store,
  List<Override> overrides = const <Override>[],
}) {
  final container = ProviderContainer(
    overrides: <Override>[
      tokenStoreProvider.overrideWithValue(store ?? InMemoryTokenStore()),
      sessionExpiryTimerProvider.overrideWithValue(idleExpiryTimer),
      ...overrides,
    ],
  );
  addTearDown(container.dispose);

  return container;
}

/// A [testContainer] that holds a session restored from [token], for tests of
/// the controllers and of screens that build their own app.
///
/// A signed-in test passes a [token] (see `testToken`) or has written one to
/// [store] already; without either the session restores as signed out.
Future<ProviderContainer> sessionContainer({
  TokenStore? store,
  AuthToken? token,
  List<Override> overrides = const <Override>[],
}) async {
  final tokens = store ?? InMemoryTokenStore();

  if (token != null) {
    await tokens.write(token);
  }

  final container = testContainer(store: tokens, overrides: overrides);
  await container.read(sessionControllerProvider.notifier).restore();

  return container;
}

/// Pumps [router], the router [routerFor] builds from the container, or
/// [home], in a window of [size], with the session of [sessionContainer], and
/// returns the container that holds it.
///
/// [afterRestore] runs once the session is restored and before the first
/// frame. [textScale] scales text as a user's large-text setting does. The
/// router and the window are torn down with the test, and the tab title that
/// an earlier test set is forgotten.
Future<ProviderContainer> pumpApp(
  WidgetTester tester, {
  GoRouter? router,
  GoRouter Function(ProviderContainer container)? routerFor,
  Widget? home,
  List<Override> overrides = const <Override>[],
  TokenStore? store,
  AuthToken? token,
  Size size = expandedWindow,
  ThemeData? theme,
  double? textScale,
  bool settle = true,
  Future<void> Function(ProviderContainer container)? afterRestore,
}) async {
  assert(
    <Object?>[router, routerFor, home].nonNulls.length == 1,
    'Give pumpApp one of a router, routerFor or a home.',
  );

  useWindow(tester, size);
  // The tab's label is static, so it would carry over from an earlier test.
  PageTitle.reset();

  if (textScale != null) {
    // The platform's setting, which the app reads as it does a user's.
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearAllTestValues);
  }

  final container = await sessionContainer(
    store: store,
    token: token,
    overrides: overrides,
  );
  await afterRestore?.call(container);

  final built = router ?? routerFor?.call(container);

  if (built != null) {
    addTearDown(built.dispose);
  }

  final resolvedTheme = theme ?? buildLightTheme();
  final app = built == null
      ? MaterialApp(theme: resolvedTheme, home: home)
      : MaterialApp.router(theme: resolvedTheme, routerConfig: built);

  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: app),
  );

  if (settle) {
    await tester.pumpAndSettle();
  }

  return container;
}
