import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/core/unload/unload_guard.dart';
import 'package:heimdall_ui/features/applications/presentation/pending_secret.dart';

/// Records what the flag asked of the browser's leave confirmation.
class _FakeUnloadGuard implements UnloadGuard {
  final List<String> calls = <String>[];

  @override
  void register() => calls.add('register');

  @override
  void unregister() => calls.add('unregister');
}

void main() {
  late _FakeUnloadGuard guard;
  late ProviderContainer container;

  setUp(() {
    guard = _FakeUnloadGuard();
    container = ProviderContainer(
      overrides: [unloadGuardProvider.overrideWithValue(guard)],
    );
  });

  tearDown(() => container.dispose());

  test('GivenNoSecretPending_WhenRead_ThenNothingIsRegistered', () {
    // When
    container.read(pendingSecretProvider);

    // Then
    expect(guard.calls, isEmpty);
  });

  // UI-37 — closing or refreshing the tab asks first while a secret is pending.
  test('GivenNoSecretPending_WhenOneIsSet_ThenTheGuardIsRegistered', () {
    // When
    container.read(pendingSecretProvider.notifier).set();

    // Then
    expect(guard.calls, <String>['register']);
  });

  test('GivenASecretPending_WhenSetAgain_ThenTheGuardIsNotRegisteredTwice', () {
    // Given
    container.read(pendingSecretProvider.notifier).set();

    // When
    container.read(pendingSecretProvider.notifier).set();

    // Then
    expect(guard.calls, <String>['register']);
  });

  test('GivenASecretPending_WhenCleared_ThenTheGuardIsUnregistered', () {
    // Given
    container.read(pendingSecretProvider.notifier).set();

    // When
    container.read(pendingSecretProvider.notifier).clear();

    // Then
    expect(guard.calls, <String>['register', 'unregister']);
  });

  test('GivenNoSecretPending_WhenCleared_ThenTheGuardIsLeftAlone', () {
    // When
    container.read(pendingSecretProvider.notifier).clear();

    // Then
    expect(guard.calls, isEmpty);
  });

  test(
    'GivenASecretPending_WhenTheFlagIsDisposed_ThenTheGuardIsUnregistered',
    () {
      // Given
      container.read(pendingSecretProvider.notifier).set();

      // When
      container.dispose();

      // Then
      expect(guard.calls, <String>['register', 'unregister']);
    },
  );
}
