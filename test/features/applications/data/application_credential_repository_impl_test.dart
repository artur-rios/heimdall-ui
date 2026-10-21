import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_api_client/export.dart';
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
    final body = adapter.bodies.single as Map<String, dynamic>;
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

    // Then
    final body = adapter.bodies.single;
    expect(
      body == null || (body as Map<String, dynamic>)['expiresAt'] == null,
      isTrue,
    );
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
}
