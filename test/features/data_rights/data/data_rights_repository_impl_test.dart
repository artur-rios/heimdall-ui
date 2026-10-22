import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_api_client/export.dart';
import 'package:heimdall_ui/core/result/result.dart';
import 'package:heimdall_ui/features/data_rights/data/data_rights_repository_impl.dart';
import 'package:heimdall_ui/features/data_rights/domain/data_rights.dart';

import '../../../support/stub_adapter.dart';

void main() {
  late StubAdapter adapter;

  ApiDataRightsRepository repositoryAnswering(StubAnswer answer) {
    adapter = StubAdapter(answer);
    final dio = Dio(BaseOptions(baseUrl: 'https://example.invalid'))
      ..httpClientAdapter = adapter;

    return ApiDataRightsRepository(AuthClient(dio));
  }

  /// The API's own refusal of a subject-rights-only token on an endpoint it is
  /// not admitted to — or, here, of a token that names nobody (AF-41a).
  const forbidden = StubAnswer(
    status: 403,
    body: <String, dynamic>{
      'success': false,
      'errors': <String>['This identity is not eligible.'],
    },
  );

  test('GivenAnExport_WhenExported_ThenTheDocumentIsIndentedJson', () async {
    // Given
    final repository = repositoryAnswering(
      const StubAnswer(
        status: 200,
        body: <String, dynamic>{
          'success': true,
          'errors': <String>[],
          'data': <String, dynamic>{
            'exportedAt': '2026-10-11T12:30:45Z',
            'subject': <String, dynamic>{
              'id': 'person-1',
              'name': 'Ada',
              'email': 'ada@example.com',
            },
            'security': <String, dynamic>{'passwordSet': true},
            'processing': <String, dynamic>{'legalBasisName': 'Contract'},
          },
        },
      ),
    );

    // When
    final result = await repository.exportMyData();

    // Then
    final export = result.valueOrNull!;
    final document = jsonDecode(export.document) as Map<String, dynamic>;
    expect((document['subject'] as Map<String, dynamic>)['name'], 'Ada');
    expect(export.document, contains('\n  "subject"'));
    expect(export.exportedAt, DateTime.utc(2026, 10, 11, 12, 30, 45));
  });

  test('GivenAnExport_WhenExported_ThenItIsAPost', () async {
    // Given
    final repository = repositoryAnswering(
      const StubAnswer(
        status: 200,
        body: <String, dynamic>{
          'success': true,
          'data': <String, dynamic>{
            'subject': <String, dynamic>{},
            'security': <String, dynamic>{},
            'processing': <String, dynamic>{},
          },
        },
      ),
    );

    // When
    await repository.exportMyData();

    // Then
    expect(adapter.methods.last, 'POST');
    expect(adapter.paths.last, '/api/auth/data-export');
  });

  test('GivenARefusal_WhenExported_ThenTheApiErrorsAreReturned', () async {
    // Given
    final repository = repositoryAnswering(forbidden);

    // When
    final result = await repository.exportMyData();

    // Then
    expect(result.failureOrNull?.kind, FailureKind.forbidden);
    expect(result.failureOrNull?.errors, <String>[
      'This identity is not eligible.',
    ]);
  });

  test('GivenAPassword_WhenErasureRequested_ThenItTravelsAsOne', () async {
    // Given
    final repository = repositoryAnswering(
      const StubAnswer(
        status: 200,
        body: <String, dynamic>{
          'success': true,
          'data': <String, dynamic>{
            'requestedAt': '2026-10-11T00:00:00Z',
            'dueAt': '2026-11-10T00:00:00Z',
            'blocked': false,
          },
        },
      ),
    );

    // When
    final result = await repository.requestErasure(
      const PasswordCredential('secret'),
    );

    // Then
    expect(adapter.paths.last, '/api/auth/erasure-request');
    expect(adapter.requests.single['password'], 'secret');
    expect(adapter.requests.single['idToken'], isNull);
    expect(result.valueOrNull?.dueAt, DateTime.utc(2026, 11, 10));
  });

  // UC-42 step 1 — a Google User confirms with a fresh Google ID token.
  test('GivenAGoogleIdToken_WhenErasureRequested_ThenItTravelsAsOne', () async {
    // Given
    final repository = repositoryAnswering(
      const StubAnswer(
        status: 200,
        body: <String, dynamic>{'success': true, 'data': <String, dynamic>{}},
      ),
    );

    // When
    await repository.requestErasure(
      const GoogleIdTokenCredential('google-id-token'),
    );

    // Then
    expect(adapter.requests.single['idToken'], 'google-id-token');
    expect(adapter.requests.single['password'], isNull);
  });

  // AF-42d — recorded, but not suspended yet.
  test('GivenABlockedErasure_WhenRequested_ThenTheReasonIsReturned', () async {
    // Given
    final repository = repositoryAnswering(
      const StubAnswer(
        status: 200,
        body: <String, dynamic>{
          'success': true,
          'data': <String, dynamic>{
            'blocked': true,
            'blockedReason': 'You are the last owner of a scope.',
          },
        },
      ),
    );

    // When
    final result = await repository.requestErasure(
      const PasswordCredential('secret'),
    );

    // Then
    expect(result.valueOrNull?.blocked, isTrue);
    expect(
      result.valueOrNull?.blockedReason,
      'You are the last owner of a scope.',
    );
  });

  // AF-42a — a wrong password is an input to correct, not a dead session.
  test(
    'GivenAWrongPassword_WhenErasureRequested_ThenItIsAValidation',
    () async {
      // Given
      final repository = repositoryAnswering(
        const StubAnswer(
          status: 401,
          body: <String, dynamic>{
            'success': false,
            'errors': <String>['The credential presented was not accepted.'],
          },
        ),
      );

      // When
      final result = await repository.requestErasure(
        const PasswordCredential('wrong'),
      );

      // Then
      expect(result.failureOrNull?.kind, FailureKind.validation);
      expect(result.failureOrNull?.errors, <String>[
        'The credential presented was not accepted.',
      ]);
    },
  );

  // AF-42c.
  test('GivenAnEarlierRequest_WhenErasureRequested_ThenAConflict', () async {
    // Given
    final repository = repositoryAnswering(
      const StubAnswer(
        status: 409,
        body: <String, dynamic>{
          'success': false,
          'errors': <String>['Erasure has already been requested.'],
        },
      ),
    );

    // When
    final result = await repository.requestErasure(
      const PasswordCredential('secret'),
    );

    // Then
    expect(result.failureOrNull?.kind, FailureKind.conflict);
  });

  // UC-44 — the ground travels as the API's number; nobody else is named.
  test(
    'GivenAGround_WhenProcessingRestricted_ThenItTravelsAsItsNumber',
    () async {
      // Given
      final expected = <RestrictionGround, int>{
        RestrictionGround.accuracyContested: 1,
        RestrictionGround.unlawfulButErasureOpposed: 2,
        RestrictionGround.neededForLegalClaim: 3,
        RestrictionGround.objectionPending: 4,
      };

      for (final MapEntry(key: ground, value: number) in expected.entries) {
        final repository = repositoryAnswering(
          StubAnswer(
            status: 200,
            body: <String, dynamic>{
              'success': true,
              'data': <String, dynamic>{
                'id': 'person-1',
                'restrictedAt': '2026-10-14T00:00:00Z',
                'ground': number,
              },
              'messages': <String>[
                'Processing of your data is restricted. Your account is '
                    'suspended until it is lifted.',
              ],
            },
          ),
        );

        // When
        final result = await repository.restrictProcessing(ground);

        // Then
        expect(result.isSuccess, isTrue);
        expect(adapter.methods.last, 'POST');
        expect(adapter.paths.last, '/api/auth/processing-restriction');
        expect(adapter.requests.single, <String, dynamic>{'ground': number});
      }
    },
  );

  // AF-44a — already restricted.
  test(
    'GivenARestriction_WhenRestrictedAgain_ThenAConflictIsReturned',
    () async {
      // Given
      final repository = repositoryAnswering(
        const StubAnswer(
          status: 409,
          body: <String, dynamic>{
            'success': false,
            'errors': <String>[
              'Processing of this account is already restricted.',
            ],
          },
        ),
      );

      // When
      final result = await repository.restrictProcessing(
        RestrictionGround.objectionPending,
      );

      // Then
      expect(result.failureOrNull?.kind, FailureKind.conflict);
      expect(result.failureOrNull?.errors, <String>[
        'Processing of this account is already restricted.',
      ]);
    },
  );

  test(
    'GivenAnUnknownGround_WhenRestricted_ThenTheApiErrorsAreReturned',
    () async {
      // Given
      final repository = repositoryAnswering(
        const StubAnswer(
          status: 400,
          body: <String, dynamic>{
            'success': false,
            'errors': <String>['RestrictionGroundUnknown'],
          },
        ),
      );

      // When
      final result = await repository.restrictProcessing(
        RestrictionGround.accuracyContested,
      );

      // Then
      expect(result.failureOrNull?.errors, <String>[
        'RestrictionGroundUnknown',
      ]);
    },
  );

  test('GivenNoConnection_WhenRestricted_ThenANetworkFailure', () async {
    // Given
    final repository = repositoryAnswering(const StubAnswer(status: 0));

    // When
    final result = await repository.restrictProcessing(
      RestrictionGround.neededForLegalClaim,
    );

    // Then
    expect(result.failureOrNull?.kind, FailureKind.network);
  });

  // UC-45 — an empty body names nobody, which the API reads as the caller.
  test('GivenARestriction_WhenLifted_ThenNoSubjectIsNamed', () async {
    // Given
    final repository = repositoryAnswering(
      const StubAnswer(
        status: 200,
        body: <String, dynamic>{
          'success': true,
          'data': <String, dynamic>{'subjectNotified': false},
        },
      ),
    );

    // When
    final result = await repository.liftOwnRestriction();

    // Then
    expect(result.isSuccess, isTrue);
    expect(adapter.paths.last, '/api/auth/processing-restriction/lift');
    expect(adapter.requests.single['subjectId'], isNull);
  });

  // AF-45a.
  test('GivenNoRestriction_WhenLifted_ThenNotFoundIsReturned', () async {
    // Given
    final repository = repositoryAnswering(
      const StubAnswer(
        status: 404,
        body: <String, dynamic>{
          'success': false,
          'errors': <String>['The identity is not restricted.'],
        },
      ),
    );

    // When
    final result = await repository.liftOwnRestriction();

    // Then
    expect(result.failureOrNull?.kind, FailureKind.notFound);
  });

  test('GivenNoConnection_WhenLifted_ThenANetworkFailure', () async {
    // Given
    final repository = repositoryAnswering(const StubAnswer(status: 0));

    // When
    final result = await repository.liftOwnRestriction();

    // Then
    expect(result.failureOrNull?.kind, FailureKind.network);
  });
}
