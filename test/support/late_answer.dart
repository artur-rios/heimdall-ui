import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart'
    show ProviderListenable, ProviderOrFamily;
import 'package:flutter_test/flutter_test.dart';

/// Starts a request on [provider], resets [reset] while it is still unanswered
/// — as the application root does to every session-scoped provider when a
/// session ends — and only then lets it be answered.
///
/// [start] makes the request, against a repository that holds its answer until
/// [answer] releases it. [provider] is listened to throughout, as the screen
/// showing it would be: without a listener Riverpod drops the late write by
/// itself, and the test would prove nothing.
Future<void> answerAfterReset<StateT>(
  ProviderContainer container,
  ProviderListenable<StateT> provider, {
  required ProviderOrFamily reset,
  required Future<Object?> Function() start,
  required void Function() answer,
}) async {
  final subscription = container.listen<StateT>(provider, (_, _) {});
  addTearDown(subscription.close);

  final pending = start();
  container.invalidate(reset);
  // Rebuilt now, as the listening screen would have it rebuilt.
  container.read(provider);
  answer();
  await pending;
}
