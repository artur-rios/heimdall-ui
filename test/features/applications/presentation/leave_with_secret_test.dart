import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:heimdall_ui/core/result/result.dart';
import 'package:heimdall_ui/core/storage/token_store.dart';
import 'package:heimdall_ui/features/applications/domain/application_credential.dart';
import 'package:heimdall_ui/features/applications/domain/application_credential_repository.dart';
import 'package:heimdall_ui/features/applications/presentation/credentials_card.dart';
import 'package:heimdall_ui/features/applications/presentation/pending_secret.dart';
import 'package:heimdall_ui/features/auth/presentation/session_controller.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepository extends Mock implements ApplicationCredentialRepository {}

/// A token naming a System Admin: payload {sub, email, role: 1}.
final String _jwt =
    'header.${base64Url.encode(utf8.encode('{"sub":"p","email":"a@b.c","role":1}'))}.signature';

void main() {
  late _MockRepository repository;
  late ProviderContainer container;
  late GoRouter router;
  late InMemoryTokenStore store;

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    when(() => repository.list('s1', 'a1')).thenAnswer(
      (_) async =>
          const Success<List<ApplicationCredential>>(<ApplicationCredential>[]),
    );
    when(() => repository.issue('s1', 'a1', expiresAt: any(named: 'expiresAt')))
        .thenAnswer(
          (_) async =>
              const Success(IssuedCredential(id: 'c9', secret: 'hds_once')),
        );

    final routerProvider = Provider<GoRouter>(
      (ref) => GoRouter(
        initialLocation: '/scopes/s1/applications/a1',
        routes: <RouteBase>[
          GoRoute(
            path: '/scopes',
            builder: (context, state) => const Scaffold(body: Text('scopes')),
          ),
          GoRoute(
            path: '/scopes/s1/applications/a1',
            builder: (context, state) => const Scaffold(
              body: SingleChildScrollView(
                child: CredentialsCard(scopeId: 's1', applicationId: 'a1'),
              ),
            ),
            onExit: (context, state) =>
                confirmLeaveWithPendingSecret(context, ref),
          ),
        ],
      ),
    );

    container = ProviderContainer(
      overrides: <Override>[
        applicationCredentialRepositoryProvider.overrideWithValue(repository),
        tokenStoreProvider.overrideWithValue(store),
      ],
    );
    addTearDown(container.dispose);
    // The guard only asks of a signed-in person.
    await store.write(AuthToken(value: _jwt, expiresAt: DateTime.utc(2030)));
    await container.read(sessionControllerProvider.notifier).restore();
    router = container.read(routerProvider);
    addTearDown(router.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> issue(WidgetTester tester) async {
    await tester.tap(find.text('Issue credential'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Issue'),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() {
    repository = _MockRepository();
    store = InMemoryTokenStore();
  });

  testWidgets(
    'GivenTheSecretDialog_WhenTheRouteIsLeft_ThenItAsksAndCancelKeepsIt',
    (tester) async {
      // Given
      await pump(tester);
      await issue(tester);
      expect(find.text('hds_once'), findsOneWidget);

      // When
      router.go('/scopes');
      await tester.pumpAndSettle();

      // Then
      expect(find.text('Leave without the secret?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('hds_once'), findsOneWidget);
      expect(find.text('scopes'), findsNothing);
    },
  );

  testWidgets('GivenTheSecretDialog_WhenLeaveIsChosen_ThenTheRouteChanges', (
    tester,
  ) async {
    // Given
    await pump(tester);
    await issue(tester);

    // When
    router.go('/scopes');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leave'));
    await tester.pumpAndSettle();

    // Then
    expect(find.text('scopes'), findsOneWidget);
    expect(container.read(pendingSecretProvider), isFalse);
  });

  testWidgets('GivenTheSecretStored_WhenTheRouteIsLeft_ThenItDoesNotAsk', (
    tester,
  ) async {
    // Given
    await pump(tester);
    await issue(tester);
    await tester.tap(find.text("I've stored it"));
    await tester.pumpAndSettle();

    // When
    router.go('/scopes');
    await tester.pumpAndSettle();

    // Then
    expect(find.text('Leave without the secret?'), findsNothing);
    expect(find.text('scopes'), findsOneWidget);
  });

  testWidgets('GivenNoSecretPending_WhenTheRouteIsLeft_ThenItDoesNotAsk', (
    tester,
  ) async {
    // Given
    await pump(tester);

    // When
    router.go('/scopes');
    await tester.pumpAndSettle();

    // Then
    expect(find.text('Leave without the secret?'), findsNothing);
    expect(find.text('scopes'), findsOneWidget);
  });

  testWidgets(
    'GivenAnIssueInFlight_WhenLeaveIsChosenAndItFails_ThenNothingThrows',
    (tester) async {
      // Given
      await pump(tester);
      final pending = Completer<Result<IssuedCredential>>();
      when(
        () => repository.issue('s1', 'a1', expiresAt: any(named: 'expiresAt')),
      ).thenAnswer((_) => pending.future);
      await tester.tap(find.text('Issue credential'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Issue'),
        ),
      );
      await tester.pump();
      router.go('/scopes');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Leave'));
      await tester.pumpAndSettle();

      // When
      pending.complete(
        const FailureResult<IssuedCredential>(
          Failure(kind: FailureKind.network, errors: <String>[]),
        ),
      );
      await tester.pumpAndSettle();

      // Then
      expect(tester.takeException(), isNull);
      expect(find.text('scopes'), findsOneWidget);
    },
  );
}
