import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_api_client/export.dart';
import 'package:heimdall_ui/core/config/app_config.dart';
import 'package:heimdall_ui/core/network/dio_client.dart';
import 'package:heimdall_ui/core/storage/token_store.dart';
import 'package:heimdall_ui/features/auth/data/auth_repository_impl.dart';
import 'package:heimdall_ui/features/auth/domain/google_sign_in_gateway.dart';
import 'package:heimdall_ui/features/auth/domain/session.dart';
import 'package:heimdall_ui/features/auth/presentation/session_controller.dart';

/// The session wired exactly as `main.dart` wires it — the real repository,
/// the real client, and the real interceptor — with only the transport
/// replaced. These are the flows whose behaviour depends on how the API's
/// status codes travel through every layer at once.
void main() {
  late _RoutingAdapter adapter;
  late InMemoryTokenStore store;
  late _FakeGoogleSignInGateway google;

  ProviderContainer wired() {
    final container = ProviderContainer(
      overrides: <Override>[
        appConfigProvider.overrideWithValue(
          const AppConfig(apiBaseUrl: 'https://example.invalid'),
        ),
        tokenStoreProvider.overrideWithValue(store),
        googleSignInGatewayProvider.overrideWithValue(google),
        authRepositoryProvider.overrideWith(
          (ref) => ApiAuthRepository(AuthClient(ref.watch(dioProvider))),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.read(dioProvider).httpClientAdapter = adapter;

    return container;
  }

  setUp(() {
    adapter = _RoutingAdapter();
    store = InMemoryTokenStore();
    google = _FakeGoogleSignInGateway();
  });

  // AF-02a — the API answers a wrong code with 401 FactorInvalid. That is a
  // code to correct, so the challenge must outlive it.
  test('GivenAChallenge_WhenTheApiRefusesTheCode_ThenItSurvives', () async {
    // Given
    adapter
      ..answer('/api/auth/login', 200, <String, dynamic>{
        'success': true,
        'errors': <String>[],
        'data': <String, dynamic>{
          'requiresTwoFactor': true,
          'challengeToken': 'challenge',
          'availableMethods': <String>['App'],
        },
      })
      ..answer('/api/auth/2fa/verify', 401, <String, dynamic>{
        'success': false,
        'errors': <String>[
          'The code or recovery code is missing, incorrect, or already used.',
        ],
      });
    final container = wired();
    final controller = container.read(sessionControllerProvider.notifier);
    await controller.restore();
    await controller.signIn(email: 'a@b.c', password: 'secret');

    // When
    final result = await controller.submitSecondFactor('000000');

    // Then
    expect(result.isSuccess, isFalse);
    expect(container.read(sessionControllerProvider), isA<Challenged>());
  });

  // AF-02b — an expired challenge is answered 401 too, and that one ends it.
  test('GivenAChallenge_WhenTheApiRefusesTheChallenge_ThenItEnds', () async {
    // Given
    adapter
      ..answer('/api/auth/login', 200, <String, dynamic>{
        'success': true,
        'errors': <String>[],
        'data': <String, dynamic>{
          'requiresTwoFactor': true,
          'challengeToken': 'challenge',
          'availableMethods': <String>['App'],
        },
      })
      ..answer('/api/auth/2fa/verify', 401, <String, dynamic>{
        'success': false,
        'errors': <String>[
          'The two-factor challenge is invalid or has expired. Log in again.',
        ],
      });
    final container = wired();
    final controller = container.read(sessionControllerProvider.notifier);
    await controller.restore();
    await controller.signIn(email: 'a@b.c', password: 'secret');

    // When
    await controller.submitSecondFactor('000000');

    // Then
    expect(container.read(sessionControllerProvider), isA<Unauthenticated>());
  });

  // AF-01a — a refused sign-in is not a session that ended.
  test(
    'GivenWrongCredentials_WhenSigningIn_ThenNoSessionIsSaidToEnd',
    () async {
      // Given
      adapter.answer('/api/auth/login', 401, <String, dynamic>{
        'success': false,
        'errors': <String>['Invalid credentials.'],
      });
      final container = wired();
      final controller = container.read(sessionControllerProvider.notifier);
      await controller.restore();
      final states = <SessionState>[];
      container.listen<SessionState>(
        sessionControllerProvider,
        (_, next) => states.add(next),
      );

      // When
      await controller.signIn(email: 'a@b.c', password: 'wrong');

      // Then
      expect(
        states.whereType<Unauthenticated>().where((s) => s.sessionExpired),
        isEmpty,
      );
    },
  );

  // AF-09d — a wrong password when disabling two-factor is answered 401. The
  // person stays signed in and is shown the refusal.
  test('GivenASession_WhenADisableIsRefused_ThenTheSessionSurvives', () async {
    // Given
    await store.write(
      AuthToken(
        value: _jwt(role: '3'),
        expiresAt: DateTime.utc(2030),
      ),
    );
    adapter.answer('/api/auth/2fa/disable', 401, <String, dynamic>{
      'success': false,
      'errors': <String>['The current password is incorrect.'],
    });
    final container = wired();
    final controller = container.read(sessionControllerProvider.notifier);
    await controller.restore();

    // When
    final result = await container
        .read(authRepositoryProvider)
        .disableTwoFactor(password: 'wrong', code: '123456');

    // Then
    expect(result.failureOrNull?.errors, <String>[
      'The current password is incorrect.',
    ]);
    expect(container.read(sessionControllerProvider), isA<Authenticated>());
    expect(await store.read(), isNotNull);
  });

  // AF-07e on a Google session — the token was refused, so the API sign-out
  // made with it would be refused too, and its 401 must not start another
  // sign-out that makes the same call again.
  test('GivenARefusedGoogleSession_WhenItEnds_ThenItEndsOnce', () async {
    // Given
    await store.write(
      AuthToken(
        value: _jwt(role: '3'),
        expiresAt: DateTime.utc(2030),
        viaGoogle: true,
      ),
    );
    adapter
      ..answer('/api/persons', 401, <String, dynamic>{
        'success': false,
        'errors': <String>[
          'The identity this token names no longer exists or has been deleted.',
        ],
      })
      ..answer('/api/auth/google/sign-out', 401, <String, dynamic>{
        'success': false,
        'errors': <String>[
          'The identity this token names no longer exists or has been deleted.',
        ],
      });
    final container = wired();
    await container.read(sessionControllerProvider.notifier).restore();

    // When
    await expectLater(
      container
          .read(dioProvider)
          .get<dynamic>('/api/persons')
          .timeout(const Duration(seconds: 5)),
      throwsA(isA<DioException>()),
    );

    // Then
    expect(
      adapter.calls.where((path) => path == '/api/auth/google/sign-out'),
      hasLength(lessThanOrEqualTo(1)),
    );
    expect(google.signOuts, 1);
    final state = container.read(sessionControllerProvider);
    expect((state as Unauthenticated).sessionExpired, isTrue);
  });

  // A deliberate sign-out from a Google session whose token the API turns
  // down mid-call still finishes, and still reaches Google.
  test('GivenAGoogleSession_WhenSignOutIsRefused_ThenItStillEnds', () async {
    // Given
    await store.write(
      AuthToken(
        value: _jwt(role: '3'),
        expiresAt: DateTime.utc(2030),
        viaGoogle: true,
      ),
    );
    adapter.answer('/api/auth/google/sign-out', 401, <String, dynamic>{
      'success': false,
      'errors': <String>['Google authentication failed.'],
    });
    final container = wired();
    final controller = container.read(sessionControllerProvider.notifier);
    await controller.restore();

    // When
    await controller.signOut().timeout(const Duration(seconds: 5));

    // Then
    expect(
      adapter.calls.where((path) => path == '/api/auth/google/sign-out'),
      hasLength(1),
    );
    expect(google.signOuts, 1);
    expect(container.read(sessionControllerProvider), isA<Unauthenticated>());
    expect(await store.read(), isNull);
  });
}

/// A token shaped as the API mints it: string claims named `id` and `role`.
String _jwt({required String role}) {
  String segment(Map<String, dynamic> json) =>
      base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');

  return '${segment(<String, dynamic>{'alg': 'HS256', 'typ': 'JWT'})}.'
      '${segment(<String, dynamic>{'id': '6f1d3a00-0000-0000-0000-000000000003', 'role': role})}.'
      'signature';
}

class _FakeGoogleSignInGateway implements GoogleSignInGateway {
  int signOuts = 0;

  @override
  GoogleSignInAvailability get availability =>
      GoogleSignInAvailability.interactive;

  @override
  Future<void> initialize() async {}

  @override
  Stream<GoogleIdTokenObtained> get idTokens =>
      const Stream<GoogleIdTokenObtained>.empty();

  @override
  Future<GoogleSignInAttempt> obtainIdToken() async =>
      const GoogleSignInCancelled();

  @override
  Future<void> signOut() async => signOuts++;
}

/// Answers each path from memory and records what was asked, so no test ever
/// reaches the network.
class _RoutingAdapter implements HttpClientAdapter {
  final Map<String, (int, Map<String, dynamic>)> _answers =
      <String, (int, Map<String, dynamic>)>{};

  final List<String> calls = <String>[];

  void answer(String path, int status, Map<String, dynamic> body) =>
      _answers[path] = (status, body);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls.add(options.path);

    // A runaway loop of requests is what one of these tests guards against;
    // failing loudly beats spinning until the suite times out.
    if (calls.length > 50) {
      throw StateError('Too many requests: $calls');
    }

    final (status, body) =
        _answers[options.path] ??
        (404, <String, dynamic>{'success': false, 'errors': <String>[]});

    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
