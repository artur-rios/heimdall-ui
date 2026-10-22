import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_api_client/export.dart';
import 'package:heimdall_ui/core/result/result.dart';
import 'package:heimdall_ui/features/audit_log/data/audit_log_repository_impl.dart';
import 'package:heimdall_ui/features/audit_log/domain/audit_entry.dart';
import 'package:heimdall_ui/features/auth/domain/session.dart';

import '../../../support/stub_adapter.dart';

void main() {
  late Dio dio;
  late StubAdapter adapter;

  ApiAuditLogRepository repositoryAnswering(StubAnswer answer) {
    adapter = StubAdapter(answer);
    dio.httpClientAdapter = adapter;

    return ApiAuditLogRepository(AuditClient(dio));
  }

  const emptyPage = StubAnswer(
    status: 200,
    body: <String, dynamic>{
      'success': true,
      'errors': <String>[],
      'data': <Map<String, dynamic>>[],
      'pageNumber': 1,
      'pageSize': 20,
      'totalItems': 0,
      'totalPages': 0,
    },
  );

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'https://example.invalid'));
  });

  test('GivenAPage_WhenListed_ThenEntriesAreMappedAsStored', () async {
    // Given — one attributed refusal and one cleared entry
    final repository = repositoryAnswering(
      const StubAnswer(
        status: 200,
        body: <String, dynamic>{
          'success': true,
          'errors': <String>[],
          'data': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'a1',
              'recordedAt': '2026-10-14T12:00:00Z',
              'actorId': '6f1c2b9e-0d4a-4c1e-9a3b-2f6d8e7a1b0c',
              'actorRole': 2,
              'action': 'CreateScopeCommand',
              'targetId': null,
              'succeeded': false,
              'failureReason': 'You are not an owner of the target scope.',
            },
            <String, dynamic>{
              'id': 'a2',
              'recordedAt': '2025-01-01T00:00:00Z',
              'actorId': null,
              'actorRole': null,
              'action': 'UpdatePersonCommand',
              'targetId': 'b7c1d2e3-0000-4000-8000-000000000001',
              'succeeded': true,
              'failureReason': null,
            },
          ],
          'pageNumber': 1,
          'pageSize': 20,
          'totalItems': 2,
          'totalPages': 1,
        },
      ),
    );

    // When
    final result = await repository.list();

    // Then
    final items = result.valueOrNull!.items;
    expect(items[0].actorRole, Role.scopeAdmin);
    expect(items[0].succeeded, isFalse);
    expect(items[0].failureReason, 'You are not an owner of the target scope.');
    expect(items[0].recordedAt, DateTime.utc(2026, 10, 14, 12));
    expect(items[1].actorId, isNull);
    expect(items[1].actorRole, isNull);
    expect(items[1].targetId, 'b7c1d2e3-0000-4000-8000-000000000001');
  });

  test('GivenEveryFilter_WhenListed_ThenEachTravelsUnderTheApiName', () async {
    // Given
    final repository = repositoryAnswering(emptyPage);
    final filter = AuditLogFilter(
      firstDay: DateTime(2026, 10, 1),
      lastDay: DateTime(2026, 10, 2),
      action: 'CreateScopeCommand',
      actorId: '6f1c2b9e-0d4a-4c1e-9a3b-2f6d8e7a1b0c',
      targetId: 'b7c1d2e3-0000-4000-8000-000000000001',
      succeeded: false,
    );

    // When
    await repository.list(filter: filter, pageNumber: 2);

    // Then
    final query = adapter.queries.single;
    final bounds = auditBoundsFor(DateTime(2026, 10, 1), DateTime(2026, 10, 2));
    expect(
      DateTime.parse(query['From'].toString()).isAtSameMomentAs(bounds.from),
      isTrue,
    );
    expect(
      DateTime.parse(query['To'].toString()).isAtSameMomentAs(bounds.to),
      isTrue,
    );
    expect(query['Action'], 'CreateScopeCommand');
    expect(query['ActorId'], '6f1c2b9e-0d4a-4c1e-9a3b-2f6d8e7a1b0c');
    expect(query['TargetId'], 'b7c1d2e3-0000-4000-8000-000000000001');
    expect(query['Succeeded'].toString(), 'false');
    expect(query['PageNumber'].toString(), '2');
  });

  test('GivenNoFilter_WhenListed_ThenNoFilterTravels', () async {
    // Given
    final repository = repositoryAnswering(emptyPage);

    // When
    await repository.list();

    // Then
    final query = adapter.queries.single;
    for (final name in <String>[
      'From',
      'To',
      'Action',
      'ActorId',
      'TargetId',
      'Succeeded',
    ]) {
      expect(query[name], isNull, reason: name);
    }
  });

  test('GivenAForbiddenAnswer_WhenListed_ThenTheFailureIsForbidden', () async {
    // Given
    final repository = repositoryAnswering(
      const StubAnswer(
        status: 403,
        body: <String, dynamic>{'success': false, 'errors': <String>[]},
      ),
    );

    // When
    final result = await repository.list();

    // Then
    expect(result.failureOrNull!.kind, FailureKind.forbidden);
  });

  test('GivenARefusalEnvelope_WhenListed_ThenTheApiMessageIsKept', () async {
    // Given
    final repository = repositoryAnswering(
      const StubAnswer(
        status: 400,
        body: <String, dynamic>{
          'success': false,
          'errors': <String>[
            'The end of the date range must not be earlier than its start.',
          ],
        },
      ),
    );

    // When
    final result = await repository.list();

    // Then
    expect(result.failureOrNull!.kind, FailureKind.validation);
    expect(result.failureOrNull!.errors, <String>[
      'The end of the date range must not be earlier than its start.',
    ]);
  });
}
