import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_api_client/export.dart';
import 'package:heimdall_ui/core/result/result.dart';
import 'package:heimdall_ui/features/scope_invitations/data/scope_invitation_repository_impl.dart';

import '../../../support/stub_adapter.dart';

void main() {
  late Dio dio;
  late StubAdapter adapter;

  ApiScopeInvitationRepository repositoryAnswering(StubAnswer answer) {
    adapter = StubAdapter(answer);
    dio.httpClientAdapter = adapter;

    return ApiScopeInvitationRepository(ScopeInvitationClient(dio));
  }

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'https://example.invalid'));
  });

  const notOpen = 'The invitation was not found or is no longer open.';

  test(
    'GivenAScopesInvitations_WhenListed_ThenTheyAreAskedForAndMapped',
    () async {
      // Given
      final repository = repositoryAnswering(
        const StubAnswer(
          status: 200,
          body: <String, dynamic>{
            'success': true,
            'errors': <String>[],
            'data': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'i1',
                'inviteeId': 'p7',
                'inviteeName': 'Hedy Lamarr',
                'inviteeEmail': 'hedy@example.com',
                'invitedByName': 'Ada',
                'createdAt': '2026-10-16T09:00:00Z',
                'expiresAt': '2026-10-23T09:00:00Z',
              },
            ],
            'pageNumber': 1,
            'pageSize': 50,
            'totalItems': 1,
            'totalPages': 1,
          },
        ),
      );

      // When
      final result = await repository.listForScope('s1');

      // Then
      expect(adapter.paths.single, '/api/scopes/s1/owner-invitations');
      expect(adapter.methods.single, 'GET');
      final item = result.valueOrNull!.items.single;
      expect(item.id, 'i1');
      expect(item.inviteeName, 'Hedy Lamarr');
      expect(item.inviteeEmail, 'hedy@example.com');
      expect(item.invitedByName, 'Ada');
      expect(item.expiresAt, DateTime.utc(2026, 10, 23, 9));
    },
  );

  test(
    'GivenAnInvitation_WhenWithdrawn_ThenItIsAddressedAndNoContentIsASuccess',
    () async {
      // Given — the API answers 204 with no body
      final repository = repositoryAnswering(const StubAnswer(status: 204));

      // When
      final result = await repository.withdraw('s1', 'i1');

      // Then
      expect(result.isSuccess, isTrue);
      expect(adapter.paths.single, '/api/scopes/s1/owner-invitations/i1');
      expect(adapter.methods.single, 'DELETE');
    },
  );

  test(
    'GivenAnEndedInvitation_WhenWithdrawn_ThenNotFoundCarriesTheApiMessage',
    () async {
      // Given
      final repository = repositoryAnswering(
        const StubAnswer(
          status: 404,
          body: <String, dynamic>{
            'success': false,
            'errors': <String>[notOpen],
          },
        ),
      );

      // When
      final result = await repository.withdraw('s1', 'i1');

      // Then
      expect(result.failureOrNull!.kind, FailureKind.notFound);
      expect(result.failureOrNull!.errors, <String>[notOpen]);
    },
  );

  test('GivenMyInvitations_WhenListed_ThenTheyAreMapped', () async {
    // Given
    final repository = repositoryAnswering(
      const StubAnswer(
        status: 200,
        body: <String, dynamic>{
          'success': true,
          'errors': <String>[],
          'data': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'i1',
              'scopeId': 's1',
              'scopeName': 'Acme',
              'invitedByName': null,
              'createdAt': '2026-10-16T09:00:00Z',
              'expiresAt': '2026-10-23T09:00:00Z',
            },
          ],
          'pageNumber': 1,
          'pageSize': 50,
          'totalItems': 1,
          'totalPages': 1,
        },
      ),
    );

    // When
    final result = await repository.listMine();

    // Then
    expect(adapter.paths.single, '/api/persons/me/scope-invitations');
    final item = result.valueOrNull!.items.single;
    expect(item.scopeName, 'Acme');
    expect(item.invitedByName, isNull);
  });

  test('GivenAnInvitation_WhenAccepted_ThenItIsPosted', () async {
    // Given
    final repository = repositoryAnswering(
      const StubAnswer(
        status: 200,
        body: <String, dynamic>{
          'success': true,
          'errors': <String>[],
          'messages': <String>['The invitation was accepted.'],
          'data': <String, dynamic>{'id': 'i1', 'scopeId': 's1'},
        },
      ),
    );

    // When
    final result = await repository.accept('i1');

    // Then
    expect(result.isSuccess, isTrue);
    expect(adapter.paths.single, '/api/scope-invitations/i1/accept');
    expect(adapter.methods.single, 'POST');
  });

  test(
    'GivenAnEndedInvitation_WhenDeclined_ThenNotFoundCarriesTheApiMessage',
    () async {
      // Given
      final repository = repositoryAnswering(
        const StubAnswer(
          status: 404,
          body: <String, dynamic>{
            'success': false,
            'errors': <String>[notOpen],
          },
        ),
      );

      // When
      final result = await repository.decline('i1');

      // Then
      expect(adapter.paths.single, '/api/scope-invitations/i1/decline');
      expect(result.failureOrNull!.kind, FailureKind.notFound);
      expect(result.failureOrNull!.errors, <String>[notOpen]);
    },
  );
}
