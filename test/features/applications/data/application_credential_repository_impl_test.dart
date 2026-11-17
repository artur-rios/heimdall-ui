import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_api_client/api.dart';
import 'package:heimdall_ui/core/result/result.dart';
import 'package:heimdall_ui/features/applications/data/application_credential_repository_impl.dart';
import 'package:heimdall_ui/features/applications/domain/application_credential.dart';

import '../../../support/stub_adapter.dart';

void main() {
  late Dio dio;
  late StubAdapter adapter;

  ApiApplicationCredentialRepository repositoryAnswering(StubAnswer answer) {
    adapter = StubAdapter(answer);
    dio.httpClientAdapter = adapter;

    return ApiApplicationCredentialRepository(ApplicationCredentialClient(dio));
  }

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'https://example.invalid'));
  });

  test('GivenCredentials_WhenListed_ThenTheyAreMapped', () async {
    // Given
    final repository = repositoryAnswering(
      const StubAnswer(
        status: 200,
        body: <String, dynamic>{
          'success': true,
          'errors': <String>[],
          'data': <String, dynamic>{
            'credentials': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'c1',
                'createdAt': '2026-10-14T10:00:00Z',
                'expiresAt': null,
                'revokedAt': null,
                'lastUsedAt': '2026-10-14T11:00:00Z',
                'live': true,
              },
              <String, dynamic>{
                'id': 'c2',
                'createdAt': '2026-10-01T10:00:00Z',
                'expiresAt': null,
                'revokedAt': '2026-10-02T10:00:00Z',
                'lastUsedAt': null,
                'live': false,
              },
            ],
          },
        },
      ),
    );

    // When
    final result = await repository.list('s1', 'a1');

    // Then
    final credentials = result.valueOrNull!;
    expect(credentials.map((c) => c.status), <CredentialStatus>[
      CredentialStatus.live,
      CredentialStatus.revoked,
    ]);
    expect(credentials.first.lastUsedAt, DateTime.utc(2026, 10, 14, 11));
    expect(adapter.paths.single, '/api/scopes/s1/applications/a1/credentials');
  });

  test('GivenAnExpiry_WhenIssued_ThenItTravelsAndTheSecretComesBack', () async {
    // Given
    final repository = repositoryAnswering(
      const StubAnswer(
        status: 201,
        body: <String, dynamic>{
          'success': true,
          'errors': <String>[],
          'data': <String, dynamic>{
            'id': 'c3',
            'secret': 'hds_abc',
            'createdAt': '2026-10-14T12:00:00Z',
            'expiresAt': '2027-03-09T23:59:59.999Z',
          },
        },
      ),
    );
    final expiry = DateTime.utc(2027, 3, 9, 23, 59, 59, 999);

    // When
    final result = await repository.issue('s1', 'a1', expiresAt: expiry);

    // Then
    expect(result.valueOrNull!.secret, 'hds_abc');
    final body = adapter.requests.single;
    expect(
      DateTime.parse(body['expiresAt'] as String).isAtSameMomentAs(expiry),
      isTrue,
    );
    expect(adapter.methods.single, 'POST');
  });

  test('GivenNoExpiry_WhenIssued_ThenNoExpiryTravels', () async {
    // Given
    final repository = repositoryAnswering(
      const StubAnswer(
        status: 201,
        body: <String, dynamic>{
          'success': true,
          'errors': <String>[],
          'data': <String, dynamic>{'id': 'c3', 'secret': 'hds_abc'},
        },
      ),
    );

    // When
    await repository.issue('s1', 'a1');

    // Then — a null expiry is left out of the body, which the API reads as
    // never.
    expect(adapter.requests.single, <String, dynamic>{});
  });

  // The generated client checks this one status itself (its body is
  // optional, so it is not left to retrofit), and the API answers 201.
  test('GivenA201_WhenIssued_ThenTheCredentialIsReturned', () async {
    // Given
    final repository = repositoryAnswering(
      const StubAnswer(
        status: 201,
        body: <String, dynamic>{
          'success': true,
          'errors': <String>[],
          'data': <String, dynamic>{
            'id': 'c4',
            'secret': 'hds_def',
            'createdAt': '2026-10-14T12:00:00Z',
            'expiresAt': null,
          },
        },
      ),
    );

    // When
    final result = await repository.issue('s1', 'a1');

    // Then
    expect(result.isSuccess, isTrue);
    expect(result.valueOrNull!.id, 'c4');
    expect(result.valueOrNull!.secret, 'hds_def');
    expect(result.valueOrNull!.expiresAt, isNull);
  });

  test(
    'GivenTheLimit_WhenIssued_ThenTheFailureIsAConflictWithTheApiMessage',
    () async {
      // Given — AF-37b
      final repository = repositoryAnswering(
        const StubAnswer(
          status: 409,
          body: <String, dynamic>{
            'success': false,
            'errors': <String>[
              'This application already has two live credentials. Revoke one before issuing another.',
            ],
          },
        ),
      );

      // When
      final result = await repository.issue('s1', 'a1');

      // Then
      expect(result.failureOrNull!.kind, FailureKind.conflict);
      expect(
        result.failureOrNull!.errors.single,
        startsWith('This application already has two live credentials.'),
      );
    },
  );

  test('GivenACredential_WhenRevoked_ThenItsPathIsAddressed', () async {
    // Given
    final repository = repositoryAnswering(
      const StubAnswer(
        status: 200,
        body: <String, dynamic>{
          'success': true,
          'errors': <String>[],
          'data': <String, dynamic>{'id': 'c1'},
        },
      ),
    );

    // When
    final result = await repository.revoke('s1', 'a1', 'c1');

    // Then
    expect(result.isSuccess, isTrue);
    expect(
      adapter.paths.single,
      '/api/scopes/s1/applications/a1/credentials/c1',
    );
    expect(adapter.methods.single, 'DELETE');
  });

  test('GivenNoConnection_WhenListed_ThenNetworkFailureIsReturned', () async {
    // Given
    final repository = repositoryAnswering(const StubAnswer(status: 0));

    // When
    final result = await repository.list('s1', 'a1');

    // Then
    expect(result.failureOrNull?.kind, FailureKind.network);
  });

  test('GivenARefusedListing_WhenListed_ThenApiErrorsAreReturned', () async {
    // Given
    final repository = repositoryAnswering(
      const StubAnswer(
        status: 200,
        body: <String, dynamic>{
          'success': false,
          'errors': <String>['Application not found.'],
        },
      ),
    );

    // When
    final result = await repository.list('s1', 'a1');

    // Then
    expect(result.failureOrNull?.errors, <String>['Application not found.']);
  });

  test('GivenAnIssueAnswerWithoutASecret_WhenIssued_ThenItFails', () async {
    // Given
    final repository = repositoryAnswering(
      const StubAnswer(
        status: 201,
        body: <String, dynamic>{
          'success': true,
          'errors': <String>[],
          'data': <String, dynamic>{'id': 'c3'},
        },
      ),
    );

    // When
    final result = await repository.issue('s1', 'a1');

    // Then
    expect(result.isSuccess, isFalse);
    expect(result.failureOrNull!.kind, FailureKind.unknown);
  });

  const refusedInEnvelope = StubAnswer(
    status: 200,
    body: <String, dynamic>{
      'success': false,
      'errors': <String>['Refused by the API.'],
    },
  );

  const refusedWithoutReason = StubAnswer(
    status: 200,
    body: <String, dynamic>{'success': false},
  );

  const acceptedWithoutData = StubAnswer(
    status: 200,
    body: <String, dynamic>{'success': true, 'errors': <String>[]},
  );

  // Issuing answers 201 and nothing else (ApplicationCredential_Issue), and
  // the generated client takes no other status for it.
  const issuedRefusedInEnvelope = StubAnswer(
    status: 201,
    body: <String, dynamic>{
      'success': false,
      'errors': <String>['Refused by the API.'],
    },
  );

  const issuedRefusedWithoutReason = StubAnswer(
    status: 201,
    body: <String, dynamic>{'success': false},
  );

  const issuedWithoutData = StubAnswer(
    status: 201,
    body: <String, dynamic>{'success': true, 'errors': <String>[]},
  );

  const noConnection = StubAnswer(status: 0);

  const incompleteResponse = <String>[
    'The API returned an incomplete response.',
  ];

  test('GivenAnApplication_WhenListed_ThenItIsAGet', () async {
    // Given
    final repository = repositoryAnswering(acceptedWithoutData);

    // When
    await repository.list('s1', 'a1');

    // Then
    expect(adapter.methods.single, 'GET');
  });

  test('GivenAnAnswerWithoutData_WhenListed_ThenNoneAreReturned', () async {
    // Given
    final repository = repositoryAnswering(acceptedWithoutData);

    // When
    final result = await repository.list('s1', 'a1');

    // Then
    expect(result.isSuccess, isTrue);
    expect(result.valueOrNull, isEmpty);
  });

  test(
    'GivenACredentialWithoutFields_WhenListed_ThenTheFallbacksAreUsed',
    () async {
      // Given
      final repository = repositoryAnswering(
        const StubAnswer(
          status: 200,
          body: <String, dynamic>{
            'success': true,
            'errors': <String>[],
            'data': <String, dynamic>{
              'credentials': <Map<String, dynamic>>[<String, dynamic>{}],
            },
          },
        ),
      );

      // When
      final result = await repository.list('s1', 'a1');

      // Then
      final credential = result.valueOrNull!.single;
      expect(credential.id, '');
      expect(credential.live, isFalse);
      expect(credential.createdAt, isNull);
      expect(credential.expiresAt, isNull);
      expect(credential.revokedAt, isNull);
      expect(credential.lastUsedAt, isNull);
    },
  );

  test('GivenACredential_WhenListed_ThenItsDatesAreMapped', () async {
    // Given
    final repository = repositoryAnswering(
      const StubAnswer(
        status: 200,
        body: <String, dynamic>{
          'success': true,
          'errors': <String>[],
          'data': <String, dynamic>{
            'credentials': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'c1',
                'createdAt': '2026-10-01T10:00:00Z',
                'expiresAt': '2027-01-01T00:00:00Z',
                'revokedAt': '2026-10-02T10:00:00Z',
                'live': false,
              },
            ],
          },
        },
      ),
    );

    // When
    final result = await repository.list('s1', 'a1');

    // Then
    final credential = result.valueOrNull!.single;
    expect(credential.id, 'c1');
    expect(credential.createdAt, DateTime.utc(2026, 10, 1, 10));
    expect(credential.expiresAt, DateTime.utc(2027));
    expect(credential.revokedAt, DateTime.utc(2026, 10, 2, 10));
  });

  test(
    'GivenARefusalWithoutReason_WhenListed_ThenNoErrorsAreReturned',
    () async {
      // Given
      final repository = repositoryAnswering(refusedWithoutReason);

      // When
      final result = await repository.list('s1', 'a1');

      // Then
      expect(result.failureOrNull?.kind, FailureKind.validation);
      expect(result.failureOrNull?.errors, isEmpty);
    },
  );

  test('GivenAForbiddenAnswer_WhenListed_ThenForbiddenIsReturned', () async {
    // Given
    final repository = repositoryAnswering(
      const StubAnswer(
        status: 403,
        body: <String, dynamic>{'success': false, 'errors': <String>[]},
      ),
    );

    // When
    final result = await repository.list('s1', 'a1');

    // Then
    expect(result.failureOrNull?.kind, FailureKind.forbidden);
  });

  test('GivenAnApplication_WhenIssued_ThenItsPathIsAddressed', () async {
    // Given
    final repository = repositoryAnswering(
      const StubAnswer(
        status: 201,
        body: <String, dynamic>{
          'success': true,
          'errors': <String>[],
          'data': <String, dynamic>{'id': 'c3', 'secret': 'hds_abc'},
        },
      ),
    );

    // When
    await repository.issue('s1', 'a1');

    // Then
    expect(adapter.paths.single, '/api/scopes/s1/applications/a1/credentials');
  });

  test('GivenAnIssuedCredential_WhenIssued_ThenEveryFieldIsMapped', () async {
    // Given
    final repository = repositoryAnswering(
      const StubAnswer(
        status: 201,
        body: <String, dynamic>{
          'success': true,
          'errors': <String>[],
          'data': <String, dynamic>{
            'id': 'c3',
            'secret': 'hds_abc',
            'createdAt': '2026-10-14T12:00:00Z',
            'expiresAt': '2027-03-09T23:59:59.999Z',
          },
        },
      ),
    );

    // When
    final result = await repository.issue('s1', 'a1');

    // Then
    final issued = result.valueOrNull!;
    expect(issued.id, 'c3');
    expect(issued.secret, 'hds_abc');
    expect(issued.createdAt, DateTime.utc(2026, 10, 14, 12));
    expect(issued.expiresAt, DateTime.utc(2027, 3, 9, 23, 59, 59, 999));
  });

  test(
    'GivenAnIssueAnswerWithoutDates_WhenIssued_ThenTheCredentialHasNone',
    () async {
      // Given
      final repository = repositoryAnswering(
        const StubAnswer(
          status: 201,
          body: <String, dynamic>{
            'success': true,
            'errors': <String>[],
            'data': <String, dynamic>{'id': 'c3', 'secret': 'hds_abc'},
          },
        ),
      );

      // When
      final result = await repository.issue('s1', 'a1');

      // Then
      expect(result.valueOrNull!.createdAt, isNull);
      expect(result.valueOrNull!.expiresAt, isNull);
    },
  );

  test('GivenAnIssueAnswerWithoutAnId_WhenIssued_ThenAnIncompleteResponseIsReturned', () async {
    // Given
    final repository = repositoryAnswering(
      const StubAnswer(
        status: 201,
        body: <String, dynamic>{
          'success': true,
          'errors': <String>[],
          'data': <String, dynamic>{'secret': 'hds_abc'},
        },
      ),
    );

    // When
    final result = await repository.issue('s1', 'a1');

    // Then
    expect(result.failureOrNull?.kind, FailureKind.unknown);
    expect(result.failureOrNull?.errors, incompleteResponse);
  });

  test('GivenAnIssueAnswerWithoutData_WhenIssued_ThenAnIncompleteResponseIsReturned', () async {
    // Given
    final repository = repositoryAnswering(issuedWithoutData);

    // When
    final result = await repository.issue('s1', 'a1');

    // Then
    expect(result.failureOrNull?.kind, FailureKind.unknown);
    expect(result.failureOrNull?.errors, incompleteResponse);
  });

  test('GivenARefusalWithinA201_WhenIssued_ThenApiErrorsAreReturned', () async {
    // Given
    final repository = repositoryAnswering(issuedRefusedInEnvelope);

    // When
    final result = await repository.issue('s1', 'a1');

    // Then
    expect(result.failureOrNull?.kind, FailureKind.validation);
    expect(result.failureOrNull?.errors, <String>['Refused by the API.']);
  });

  test(
    'GivenARefusalWithoutReason_WhenIssued_ThenNoErrorsAreReturned',
    () async {
      // Given
      final repository = repositoryAnswering(issuedRefusedWithoutReason);

      // When
      final result = await repository.issue('s1', 'a1');

      // Then
      expect(result.failureOrNull?.kind, FailureKind.validation);
      expect(result.failureOrNull?.errors, isEmpty);
    },
  );

  test('GivenNoConnection_WhenIssued_ThenNetworkFailureIsReturned', () async {
    // Given
    final repository = repositoryAnswering(noConnection);

    // When
    final result = await repository.issue('s1', 'a1');

    // Then
    expect(result.failureOrNull?.kind, FailureKind.network);
  });

  test(
    'GivenARefusalWithinA200_WhenRevoked_ThenApiErrorsAreReturned',
    () async {
      // Given
      final repository = repositoryAnswering(refusedInEnvelope);

      // When
      final result = await repository.revoke('s1', 'a1', 'c1');

      // Then
      expect(result.failureOrNull?.kind, FailureKind.validation);
      expect(result.failureOrNull?.errors, <String>['Refused by the API.']);
    },
  );

  test(
    'GivenARefusalWithoutReason_WhenRevoked_ThenNoErrorsAreReturned',
    () async {
      // Given
      final repository = repositoryAnswering(refusedWithoutReason);

      // When
      final result = await repository.revoke('s1', 'a1', 'c1');

      // Then
      expect(result.failureOrNull?.kind, FailureKind.validation);
      expect(result.failureOrNull?.errors, isEmpty);
    },
  );

  test('GivenAnUnknownCredential_WhenRevoked_ThenNotFoundIsReturned', () async {
    // Given
    final repository = repositoryAnswering(
      const StubAnswer(
        status: 404,
        body: <String, dynamic>{
          'success': false,
          'errors': <String>['Credential not found.'],
        },
      ),
    );

    // When
    final result = await repository.revoke('s1', 'a1', 'missing');

    // Then
    expect(result.failureOrNull?.kind, FailureKind.notFound);
    expect(result.failureOrNull?.errors, <String>['Credential not found.']);
  });

  test('GivenNoConnection_WhenRevoked_ThenNetworkFailureIsReturned', () async {
    // Given
    final repository = repositoryAnswering(noConnection);

    // When
    final result = await repository.revoke('s1', 'a1', 'c1');

    // Then
    expect(result.failureOrNull?.kind, FailureKind.network);
  });
}
