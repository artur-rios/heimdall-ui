import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/core/storage/token_store.dart';
import 'package:heimdall_ui/features/auth/domain/auth_repository.dart';
import 'package:heimdall_ui/features/auth/domain/google_sign_in_gateway.dart';
import 'package:heimdall_ui/features/auth/presentation/session_controller.dart';
import 'package:heimdall_ui/shared/layout/app_shell.dart';
import 'package:heimdall_ui/shared/widgets/page_title.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/idle_expiry_timer.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockGoogle extends Mock implements GoogleSignInGateway {}

// role 3 (User).
const String _jwt = 'header.eyJzdWIiOiIxIiwicm9sZSI6M30.signature';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<String> titles;

  setUp(() {
    PageTitle.reset();
    titles = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'SystemChrome.setApplicationSwitcherDescription') {
            titles.add((call.arguments as Map)['label'] as String);
          }

          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Future<void> pumpShell(WidgetTester tester, Widget title) async {
    final store = InMemoryTokenStore();
    await store.write(AuthToken(value: _jwt, expiresAt: DateTime.utc(2100)));
    final container = ProviderContainer(
      overrides: <Override>[
        authRepositoryProvider.overrideWithValue(_MockAuthRepository()),
        googleSignInGatewayProvider.overrideWithValue(_MockGoogle()),
        tokenStoreProvider.overrideWithValue(store),
        sessionExpiryTimerProvider.overrideWithValue(idleExpiryTimer),
      ],
    );
    addTearDown(container.dispose);
    await container.read(sessionControllerProvider.notifier).restore();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: AppShell(
            currentRoute: '/',
            title: title,
            body: const SizedBox(),
          ),
        ),
      ),
    );
  }

  testWidgets('GivenAShellScreen_WhenShown_ThenTheTabIsNamedAfterIt', (
    tester,
  ) async {
    await pumpShell(tester, const Text('Permissions'));

    expect(titles.last, 'Permissions - Heimdall');
  });

  testWidgets('GivenATitleThatIsNotText_WhenShown_ThenNoTitleIsSet', (
    tester,
  ) async {
    await pumpShell(tester, const Icon(Icons.home));

    // The application's own title is empty here; the shell adds none.
    expect(titles.where((title) => title.isNotEmpty), isEmpty);
  });
}
