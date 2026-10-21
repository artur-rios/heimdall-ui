import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/core/result/result.dart';
import 'package:heimdall_ui/core/scope/scope_source.dart';
import 'package:heimdall_ui/core/storage/token_store.dart';
import 'package:heimdall_ui/features/auth/domain/auth_repository.dart';
import 'package:heimdall_ui/features/auth/domain/google_sign_in_gateway.dart';
import 'package:heimdall_ui/features/auth/domain/session.dart';
import 'package:heimdall_ui/features/auth/presentation/session_controller.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockGoogle extends Mock implements GoogleSignInGateway {}

const String _jwt = 'header.eyJzdWIiOiIxIiwicm9sZSI6M30.signature';

/// #182 — the widget tester's clock is a fake one, so an expiry hours away is
/// reached by pumping. The token's own expiry is read from the real clock when
/// the timer is armed, which is what the durations below are measured from.
void main() {
  late InMemoryTokenStore store;
  late _MockAuthRepository repository;
  late ProviderContainer container;

  AuthToken tokenExpiringIn(Duration life) =>
      AuthToken(value: _jwt, expiresAt: DateTime.now().toUtc().add(life));

  SessionController start() {
    container = ProviderContainer(
      overrides: <Override>[
        authRepositoryProvider.overrideWithValue(repository),
        googleSignInGatewayProvider.overrideWithValue(_MockGoogle()),
        scopeSourceProvider.overrideWithValue(const FixedScopeSource(null)),
        tokenStoreProvider.overrideWithValue(store),
        sessionExpiryTimerProvider.overrideWithValue(Timer.new),
      ],
    );
    addTearDown(container.dispose);

    return container.read(sessionControllerProvider.notifier);
  }

  SessionState session() => container.read(sessionControllerProvider);

  bool expired() => switch (session()) {
    Unauthenticated(:final sessionExpired) => sessionExpired,
    _ => false,
  };

  setUp(() {
    store = InMemoryTokenStore();
    repository = _MockAuthRepository();
  });

  testWidgets('GivenARestoredSession_WhenItsExpiryPasses_ThenItEndsAsExpired', (
    tester,
  ) async {
    await store.write(tokenExpiringIn(const Duration(hours: 1)));
    final controller = start();
    await controller.restore();

    await tester.pump(const Duration(minutes: 59));
    expect(session(), isA<Authenticated>());

    await tester.pump(const Duration(minutes: 2));

    expect(expired(), isTrue);
  });

  testWidgets('GivenASessionThatEndedEarly_WhenItsExpiryPasses_ThenNothing', (
    tester,
  ) async {
    await store.write(tokenExpiringIn(const Duration(hours: 1)));
    final controller = start();
    await controller.restore();
    await controller.signOut();

    await tester.pump(const Duration(hours: 2));

    expect(session(), isA<Unauthenticated>());
    expect(expired(), isFalse);
  });

  testWidgets('GivenAReplacedToken_WhenTheFirstExpires_ThenTheSessionLives', (
    tester,
  ) async {
    await store.write(tokenExpiringIn(const Duration(hours: 1)));
    final controller = start();
    await controller.restore();
    await store.write(tokenExpiringIn(const Duration(hours: 5)));
    await controller.restore();

    await tester.pump(const Duration(hours: 2));
    expect(session(), isA<Authenticated>());

    await tester.pump(const Duration(hours: 4));
    expect(expired(), isTrue);
  });

  testWidgets('GivenATokenAlreadyExpired_WhenSignedIn_ThenItEndsAtOnce', (
    tester,
  ) async {
    when(
      () => repository.login(
        email: 'a@b.c',
        password: 'secret',
        scopeId: any(named: 'scopeId'),
      ),
    ).thenAnswer(
      (_) async => Success<LoginOutcome>(
        LoggedIn(tokenExpiringIn(const Duration(seconds: -5))),
      ),
    );
    final controller = start();
    await controller.restore();
    await controller.signIn(email: 'a@b.c', password: 'secret');

    await tester.pumpAndSettle();

    expect(expired(), isTrue);
  });
}
