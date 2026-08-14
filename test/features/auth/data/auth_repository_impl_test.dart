import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_api_client/export.dart';
import 'package:heimdall_ui/core/result/result.dart';
import 'package:heimdall_ui/features/auth/data/auth_repository_impl.dart';
import 'package:heimdall_ui/features/auth/domain/auth_repository.dart';

void main() {
  late Dio dio;
  late ApiAuthRepository repository;
  late _StubAdapter adapter;

  ApiAuthRepository repositoryAnswering(_Answer answer) {
    adapter = _StubAdapter(answer);
    dio.httpClientAdapter = adapter;

    return ApiAuthRepository(AuthClient(dio));
  }

  /// A verify response carrying a usable token.
  const acceptedChallenge = _Answer(
    status: 200,
    body: <String, dynamic>{
      'success': true,
      'errors': <String>[],
      'data': <String, dynamic>{
        'token': 'jwt',
        'expiresAt': '2030-01-01T00:00:00Z',
      },
    },
  );

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'https://example.invalid'));
  });

  test('GivenTokenResponse_WhenLoggingIn_ThenLoggedInIsReturned', () async {
    // Given
    repository = repositoryAnswering(
      const _Answer(
        status: 200,
        body: <String, dynamic>{
          'success': true,
          'errors': <String>[],
          'data': <String, dynamic>{
            'token': 'jwt',
            'expiresAt': '2030-01-01T00:00:00Z',
            'requiresTwoFactor': false,
          },
        },
      ),
    );

    // When
    final result = await repository.login(email: 'a@b.c', password: 'secret');

    // Then
    expect(result.valueOrNull, isA<LoggedIn>());
    expect((result.valueOrNull! as LoggedIn).token.value, 'jwt');
  });

  // AF-01c — the API answers with a challenge instead of a token.
  test(
    'GivenTwoFactorResponse_WhenLoggingIn_ThenTwoFactorRequiredIsReturned',
    () async {
      // Given
      repository = repositoryAnswering(
        const _Answer(
          status: 200,
          body: <String, dynamic>{
            'success': true,
            'errors': <String>[],
            'data': <String, dynamic>{
              'requiresTwoFactor': true,
              'challengeToken': 'challenge',
              'availableMethods': <String>['Totp', 'Email'],
            },
          },
        ),
      );

      // When
      final result = await repository.login(email: 'a@b.c', password: 'secret');

      // Then
      final outcome = result.valueOrNull;
      expect(outcome, isA<TwoFactorRequired>());
      expect((outcome! as TwoFactorRequired).challengeToken, 'challenge');
      expect((outcome as TwoFactorRequired).availableMethods, <String>[
        'Totp',
        'Email',
      ]);
    },
  );

  // AF-01a — an unsuccessful envelope carries the reason in `errors`.
  test(
    'GivenRejectedEnvelope_WhenLoggingIn_ThenApiErrorsAreReturned',
    () async {
      // Given
      repository = repositoryAnswering(
        const _Answer(
          status: 200,
          body: <String, dynamic>{
            'success': false,
            'errors': <String>['Invalid email or password.'],
            'data': null,
          },
        ),
      );

      // When
      final result = await repository.login(email: 'a@b.c', password: 'wrong');

      // Then
      expect(result.failureOrNull?.errors, <String>[
        'Invalid email or password.',
      ]);
    },
  );

  // AF-01a — the API answers 401 for every rejection, body and all.
  test(
    'GivenUnauthorizedStatus_WhenLoggingIn_ThenApiErrorsAreReturned',
    () async {
      // Given
      repository = repositoryAnswering(
        const _Answer(
          status: 401,
          body: <String, dynamic>{
            'success': false,
            'errors': <String>['Invalid credentials.'],
          },
        ),
      );

      // When
      final result = await repository.login(email: 'a@b.c', password: 'wrong');

      // Then
      expect(result.failureOrNull?.kind, FailureKind.unauthorized);
      expect(result.failureOrNull?.errors, <String>['Invalid credentials.']);
    },
  );

  // AF-01d — the API could not be reached at all.
  test(
    'GivenTransportFailure_WhenLoggingIn_ThenNetworkFailureIsReturned',
    () async {
      // Given
      repository = repositoryAnswering(const _Answer(status: 0));

      // When
      final result = await repository.login(email: 'a@b.c', password: 'secret');

      // Then
      expect(result.failureOrNull?.kind, FailureKind.network);
    },
  );

  // A successful envelope that carries neither a token nor a challenge.
  test('GivenIncompleteEnvelope_WhenLoggingIn_ThenFailureIsReturned', () async {
    // Given
    repository = repositoryAnswering(
      const _Answer(
        status: 200,
        body: <String, dynamic>{
          'success': true,
          'errors': <String>[],
          'data': <String, dynamic>{'requiresTwoFactor': false},
        },
      ),
    );

    // When
    final result = await repository.login(email: 'a@b.c', password: 'secret');

    // Then
    expect(result.failureOrNull, isNotNull);
  });

  test('GivenTokenResponse_WhenVerifying_ThenTheTokenIsReturned', () async {
    // Given
    repository = repositoryAnswering(acceptedChallenge);

    // When
    final result = await repository.verifySecondFactor(
      challengeToken: 'challenge',
      code: '123456',
    );

    // Then
    expect(result.valueOrNull?.value, 'jwt');
  });

  test('GivenGeneratedCode_WhenVerifying_ThenItIsSentAsTheCode', () async {
    // Given
    repository = repositoryAnswering(acceptedChallenge);

    // When
    await repository.verifySecondFactor(
      challengeToken: 'challenge',
      code: '123456',
    );

    // Then
    expect(adapter.requests.single['code'], '123456');
  });

  // AF-02d — the API checks a recovery code against a different secret, so it
  // travels in its own field.
  test(
    'GivenRecoveryCode_WhenVerifying_ThenItIsSentAsTheRecoveryCode',
    () async {
      // Given
      repository = repositoryAnswering(acceptedChallenge);

      // When
      await repository.verifySecondFactor(
        challengeToken: 'challenge',
        code: 'recovery-code',
        isRecoveryCode: true,
      );

      // Then
      expect(adapter.requests.single['recoveryCode'], 'recovery-code');
    },
  );

  // AF-02a — an unsuccessful envelope carries the reason in `errors`.
  test(
    'GivenRejectedEnvelope_WhenVerifying_ThenApiErrorsAreReturned',
    () async {
      // Given
      repository = repositoryAnswering(
        const _Answer(
          status: 200,
          body: <String, dynamic>{
            'success': false,
            'errors': <String>['The code is incorrect.'],
            'data': null,
          },
        ),
      );

      // When
      final result = await repository.verifySecondFactor(
        challengeToken: 'challenge',
        code: '000000',
      );

      // Then
      expect(result.failureOrNull?.errors, <String>['The code is incorrect.']);
    },
  );

  // AF-02b — a challenge the API no longer recognises comes back as a 401.
  test(
    'GivenUnauthorizedStatus_WhenVerifying_ThenUnauthorizedFailureIsReturned',
    () async {
      // Given
      repository = repositoryAnswering(
        const _Answer(
          status: 401,
          body: <String, dynamic>{
            'success': false,
            'errors': <String>['The challenge has expired.'],
          },
        ),
      );

      // When
      final result = await repository.verifySecondFactor(
        challengeToken: 'stale',
        code: '123456',
      );

      // Then
      expect(result.failureOrNull?.kind, FailureKind.unauthorized);
    },
  );

  test(
    'GivenTransportFailure_WhenVerifying_ThenNetworkFailureIsReturned',
    () async {
      // Given
      repository = repositoryAnswering(const _Answer(status: 0));

      // When
      final result = await repository.verifySecondFactor(
        challengeToken: 'challenge',
        code: '123456',
      );

      // Then
      expect(result.failureOrNull?.kind, FailureKind.network);
    },
  );

  test(
    'GivenAcceptedEnvelope_WhenRequestingRecovery_ThenSuccessIsReturned',
    () async {
      // Given
      repository = repositoryAnswering(
        const _Answer(
          status: 200,
          body: <String, dynamic>{
            'success': true,
            'errors': <String>[],
            'data': null,
          },
        ),
      );

      // When
      final result = await repository.requestPasswordRecovery(email: 'a@b.c');

      // Then
      expect(result.isSuccess, isTrue);
    },
  );

  test(
    'GivenAnAddress_WhenRequestingRecovery_ThenItIsSentAsTheEmail',
    () async {
      // Given
      repository = repositoryAnswering(
        const _Answer(
          status: 200,
          body: <String, dynamic>{
            'success': true,
            'errors': <String>[],
            'data': null,
          },
        ),
      );

      // When
      await repository.requestPasswordRecovery(email: 'a@b.c');

      // Then
      expect(adapter.requests.single['email'], 'a@b.c');
    },
  );

  // The neutral confirmation: the API answers an unknown address the same way,
  // and nothing here reads any further into it.
  test(
    'GivenUnknownAddress_WhenRequestingRecovery_ThenSuccessIsReturned',
    () async {
      // Given
      repository = repositoryAnswering(
        const _Answer(
          status: 200,
          body: <String, dynamic>{
            'success': true,
            'errors': <String>[],
            'data': null,
          },
        ),
      );

      // When
      final result = await repository.requestPasswordRecovery(
        email: 'nobody@nowhere.invalid',
      );

      // Then
      expect(result.isSuccess, isTrue);
    },
  );

  test(
    'GivenRejectedEnvelope_WhenRequestingRecovery_ThenApiErrorsAreReturned',
    () async {
      // Given
      repository = repositoryAnswering(
        const _Answer(
          status: 400,
          body: <String, dynamic>{
            'success': false,
            'errors': <String>['Email is not in a valid format.'],
          },
        ),
      );

      // When
      final result = await repository.requestPasswordRecovery(email: 'nope');

      // Then
      expect(result.failureOrNull?.errors, <String>[
        'Email is not in a valid format.',
      ]);
    },
  );

  // AF-03b — the API could not be reached at all.
  test(
    'GivenTransportFailure_WhenRequestingRecovery_ThenNetworkFailureIsReturned',
    () async {
      // Given
      repository = repositoryAnswering(const _Answer(status: 0));

      // When
      final result = await repository.requestPasswordRecovery(email: 'a@b.c');

      // Then
      expect(result.failureOrNull?.kind, FailureKind.network);
    },
  );

  test('GivenAcceptedEnvelope_WhenResetting_ThenSuccessIsReturned', () async {
    // Given
    repository = repositoryAnswering(
      const _Answer(
        status: 200,
        body: <String, dynamic>{
          'success': true,
          'errors': <String>[],
          'data': null,
        },
      ),
    );

    // When
    final result = await repository.resetPassword(
      token: 'reset-token',
      newPassword: 'new-secret',
    );

    // Then
    expect(result.isSuccess, isTrue);
  });

  test('GivenAResetToken_WhenResetting_ThenTokenAndPasswordAreSent', () async {
    // Given
    repository = repositoryAnswering(
      const _Answer(
        status: 200,
        body: <String, dynamic>{
          'success': true,
          'errors': <String>[],
          'data': null,
        },
      ),
    );

    // When
    await repository.resetPassword(
      token: 'reset-token',
      newPassword: 'new-secret',
    );

    // Then
    expect(adapter.requests.single['token'], 'reset-token');
    expect(adapter.requests.single['newPassword'], 'new-secret');
  });

  // AF-04b — an unknown, expired, or spent token answers 400 by name.
  test('GivenRejectedToken_WhenResetting_ThenApiErrorsAreReturned', () async {
    // Given
    repository = repositoryAnswering(
      const _Answer(
        status: 400,
        body: <String, dynamic>{
          'success': false,
          'errors': <String>['The reset token has expired.'],
        },
      ),
    );

    // When
    final result = await repository.resetPassword(
      token: 'stale',
      newPassword: 'new-secret',
    );

    // Then
    expect(result.failureOrNull?.errors, <String>[
      'The reset token has expired.',
    ]);
  });

  // AF-04d — the envelope reports failure within a 200.
  test(
    'GivenRejectedPasswordEnvelope_WhenResetting_ThenApiErrorsAreReturned',
    () async {
      // Given
      repository = repositoryAnswering(
        const _Answer(
          status: 200,
          body: <String, dynamic>{
            'success': false,
            'errors': <String>['Password must be at least 8 characters.'],
            'data': null,
          },
        ),
      );

      // When
      final result = await repository.resetPassword(
        token: 'reset-token',
        newPassword: 'short',
      );

      // Then
      expect(result.failureOrNull?.errors, <String>[
        'Password must be at least 8 characters.',
      ]);
    },
  );

  test(
    'GivenTransportFailure_WhenResetting_ThenNetworkFailureIsReturned',
    () async {
      // Given
      repository = repositoryAnswering(const _Answer(status: 0));

      // When
      final result = await repository.resetPassword(
        token: 'reset-token',
        newPassword: 'new-secret',
      );

      // Then
      expect(result.failureOrNull?.kind, FailureKind.network);
    },
  );

  test('GivenAVerificationToken_WhenVerifying_ThenTheTokenIsSent', () async {
    // Given
    repository = repositoryAnswering(
      const _Answer(
        status: 200,
        body: <String, dynamic>{
          'success': true,
          'messages': <String>[],
          'errors': <String>[],
          'data': null,
        },
      ),
    );

    // When
    await repository.verifyEmail(token: 'verification-token');

    // Then
    expect(adapter.requests.single['token'], 'verification-token');
  });

  // AF-05d — an address already verified answers successfully, and only the
  // envelope's messages say which of the two happened.
  test('GivenAcceptedEnvelope_WhenVerifying_ThenMessagesAreReturned', () async {
    // Given
    repository = repositoryAnswering(
      const _Answer(
        status: 200,
        body: <String, dynamic>{
          'success': true,
          'messages': <String>['This address was already verified.'],
          'errors': <String>[],
          'data': null,
        },
      ),
    );

    // When
    final result = await repository.verifyEmail(token: 'spent-token');

    // Then
    expect(result.valueOrNull, <String>['This address was already verified.']);
  });

  // AF-05b — an unknown, expired, or spent token answers 400 by name.
  test('GivenRejectedToken_WhenVerifying_ThenApiErrorsAreReturned', () async {
    // Given
    repository = repositoryAnswering(
      const _Answer(
        status: 400,
        body: <String, dynamic>{
          'success': false,
          'errors': <String>['The verification token has expired.'],
        },
      ),
    );

    // When
    final result = await repository.verifyEmail(token: 'stale');

    // Then
    expect(result.failureOrNull?.errors, <String>[
      'The verification token has expired.',
    ]);
  });

  test(
    'GivenTransportFailure_WhenVerifying_ThenNetworkFailureIsReturned',
    () async {
      // Given
      repository = repositoryAnswering(const _Answer(status: 0));

      // When
      final result = await repository.verifyEmail(token: 'verification-token');

      // Then
      expect(result.failureOrNull?.kind, FailureKind.network);
    },
  );

  // AF-05c — the resend takes no body; the person comes from the token.
  test('GivenASession_WhenResending_ThenNoBodyIsSent', () async {
    // Given
    repository = repositoryAnswering(
      const _Answer(
        status: 200,
        body: <String, dynamic>{
          'success': true,
          'errors': <String>[],
          'data': null,
        },
      ),
    );

    // When
    final result = await repository.resendVerificationEmail();

    // Then
    expect(result.isSuccess, isTrue);
    expect(adapter.requests, isEmpty);
  });

  test('GivenRejectedResend_WhenResending_ThenApiErrorsAreReturned', () async {
    // Given
    repository = repositoryAnswering(
      const _Answer(
        status: 400,
        body: <String, dynamic>{
          'success': false,
          'errors': <String>['This address is already verified.'],
        },
      ),
    );

    // When
    final result = await repository.resendVerificationEmail();

    // Then
    expect(result.failureOrNull?.errors, <String>[
      'This address is already verified.',
    ]);
  });

  test(
    'GivenTransportFailure_WhenResending_ThenNetworkFailureIsReturned',
    () async {
      // Given
      repository = repositoryAnswering(const _Answer(status: 0));

      // When
      final result = await repository.resendVerificationEmail();

      // Then
      expect(result.failureOrNull?.kind, FailureKind.network);
    },
  );

  /// A Google exchange answering with a usable token.
  const acceptedGoogleExchange = _Answer(
    status: 200,
    body: <String, dynamic>{
      'success': true,
      'errors': <String>[],
      'data': <String, dynamic>{
        'token': 'jwt',
        'expiresAt': '2030-01-01T00:00:00Z',
      },
    },
  );

  test(
    'GivenAnIdToken_WhenSigningInWithGoogle_ThenTheTokenIsReturned',
    () async {
      // Given
      repository = repositoryAnswering(acceptedGoogleExchange);

      // When
      final result = await repository.signInWithGoogle(
        idToken: 'google-id-token',
        scopeId: 'scope-public-id',
      );

      // Then
      expect(result.valueOrNull?.value, 'jwt');
    },
  );

  // The session must remember it came from Google, so sign-out can tell it.
  test(
    'GivenAnIdToken_WhenSigningInWithGoogle_ThenTheTokenIsMarkedGoogle',
    () async {
      // Given
      repository = repositoryAnswering(acceptedGoogleExchange);

      // When
      final result = await repository.signInWithGoogle(
        idToken: 'google-id-token',
        scopeId: 'scope-public-id',
      );

      // Then
      expect(result.valueOrNull?.viaGoogle, isTrue);
    },
  );

  test('GivenAScope_WhenSigningInWithGoogle_ThenBothTravelInTheBody', () async {
    // Given
    repository = repositoryAnswering(acceptedGoogleExchange);

    // When
    await repository.signInWithGoogle(
      idToken: 'google-id-token',
      scopeId: 'scope-public-id',
    );

    // Then
    expect(adapter.requests.single['idToken'], 'google-id-token');
    expect(adapter.requests.single['scopeId'], 'scope-public-id');
  });

  // AF-06b — the scope has Google Sign-In switched off, which the API answers
  // 403 for a missing, deleted, and disabled scope alike.
  test(
    'GivenDisabledScope_WhenSigningInWithGoogle_ThenApiErrorsAreReturned',
    () async {
      // Given
      repository = repositoryAnswering(
        const _Answer(
          status: 403,
          body: <String, dynamic>{
            'success': false,
            'errors': <String>['Google Sign-In is not enabled for this scope.'],
          },
        ),
      );

      // When
      final result = await repository.signInWithGoogle(
        idToken: 'google-id-token',
        scopeId: 'scope-public-id',
      );

      // Then
      expect(result.failureOrNull?.kind, FailureKind.forbidden);
      expect(result.failureOrNull?.errors, <String>[
        'Google Sign-In is not enabled for this scope.',
      ]);
    },
  );

  // AF-06d — the API refuses the ID token, answering 401 as login does.
  test(
    'GivenRejectedIdToken_WhenSigningInWithGoogle_ThenApiErrorsAreReturned',
    () async {
      // Given
      repository = repositoryAnswering(
        const _Answer(
          status: 401,
          body: <String, dynamic>{
            'success': false,
            'errors': <String>['That Google account could not be signed in.'],
          },
        ),
      );

      // When
      final result = await repository.signInWithGoogle(
        idToken: 'forged',
        scopeId: 'scope-public-id',
      );

      // Then
      expect(result.failureOrNull?.kind, FailureKind.unauthorized);
    },
  );

  test(
    'GivenTransportFailure_WhenSigningInWithGoogle_ThenNetworkFailureIsReturned',
    () async {
      // Given
      repository = repositoryAnswering(const _Answer(status: 0));

      // When
      final result = await repository.signInWithGoogle(
        idToken: 'google-id-token',
      );

      // Then
      expect(result.failureOrNull?.kind, FailureKind.network);
    },
  );

  // The sign-out takes no body: the Google User comes from the bearer token.
  test('GivenAGoogleSession_WhenSigningOut_ThenNoBodyIsSent', () async {
    // Given
    repository = repositoryAnswering(
      const _Answer(
        status: 200,
        body: <String, dynamic>{
          'success': true,
          'errors': <String>[],
          'data': null,
        },
      ),
    );

    // When
    final result = await repository.signOutFromGoogle();

    // Then
    expect(result.isSuccess, isTrue);
    expect(adapter.requests, isEmpty);
  });

  test(
    'GivenRejectedSignOut_WhenSigningOut_ThenApiErrorsAreReturned',
    () async {
      // Given
      repository = repositoryAnswering(
        const _Answer(
          status: 401,
          body: <String, dynamic>{
            'success': false,
            'errors': <String>['Not a Google session.'],
          },
        ),
      );

      // When
      final result = await repository.signOutFromGoogle();

      // Then
      expect(result.failureOrNull?.errors, <String>['Not a Google session.']);
    },
  );
}

/// What the stub answers with. A [status] of zero stands for a connection that
/// never got as far as a response.
class _Answer {
  const _Answer({required this.status, this.body});

  final int status;
  final Map<String, dynamic>? body;
}

/// Answers from memory, so no test reaches the network.
class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this._answer);

  final _Answer _answer;

  /// The bodies it was asked to send, so a test can assert which field a value
  /// travelled in.
  final List<Map<String, dynamic>> requests = <Map<String, dynamic>>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (requestStream != null) {
      final bytes = <int>[];

      await for (final chunk in requestStream) {
        bytes.addAll(chunk);
      }

      if (bytes.isNotEmpty) {
        if (jsonDecode(utf8.decode(bytes)) case final Map<String, dynamic> b) {
          requests.add(b);
        }
      }
    }

    if (_answer.status == 0) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'No route to host',
      );
    }

    return ResponseBody.fromString(
      jsonEncode(_answer.body),
      _answer.status,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
