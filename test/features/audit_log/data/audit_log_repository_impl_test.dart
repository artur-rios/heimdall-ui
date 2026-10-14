import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_api_client/export.dart';
import 'package:heimdall_ui/core/result/result.dart';
import 'package:heimdall_ui/features/audit_log/data/audit_log_repository_impl.dart';
import 'package:heimdall_ui/features/audit_log/domain/audit_entry.dart';
import 'package:heimdall_ui/features/auth/domain/session.dart';

void main() {
  late Dio dio;
  late _StubAdapter adapter;

  ApiAuditLogRepository repositoryAnswering(_Answer answer) {
    adapter = _StubAdapter(answer);
    dio.httpClientAdapter = adapter;

    return ApiAuditLogRepository(AuditClient(dio));
  }

  const emptyPage = _Answer(
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
      const _Answer(
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
      const _Answer(
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
      const _Answer(
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

class _Answer {
  const _Answer({required this.status, this.body});

  final int status;
  final Map<String, dynamic>? body;
}

/// Answers from memory, so no test reaches the network.
class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this._answer);

  final _Answer _answer;

  /// The query parameters it was asked for, so a test can assert which filters
  /// actually travelled.
  final List<Map<String, dynamic>> queries = <Map<String, dynamic>>[];

  /// The request bodies it was sent, as JSON, so a test can assert which
  /// fields actually travelled.
  final List<Object?> bodies = <Object?>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    queries.add(options.queryParameters);
    bodies.add(
      options.data == null ? null : jsonDecode(jsonEncode(options.data)),
    );

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
