// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/audit_log_entry_output_paginated_output.dart';

part 'audit_client.g.dart';

@RestApi()
abstract class AuditClient {
  factory AuditClient(Dio dio, {String? baseUrl}) = _AuditClient;

  /// Lists the audit trail (UC-48, FR-AT-01/02), newest first. System Admin only. Every filter is.
  /// optional and they combine: `from`/`to` bound when an entry was recorded (UTC,.
  /// inclusive), `actorId` and `targetId` are public ids, `action` is the exact.
  /// command type name (e.g. `CreateScopeCommand`), and `succeeded=false` lists only.
  /// refusals.
  ///
  /// Entries are shown as stored. An actor the retention pass has cleared (NFR-21) is.
  /// `null` and is never reconstructed, so filtering by `actorId` cannot find entries.
  /// whose attribution has been cleared. A Scope Admin is refused: the trail has no scope.
  /// column, and an old entry's target may be gone, so it cannot be divided by scope reliably.
  /// Reading the trail is not itself audited.
  ///
  /// **Requires role:** System Admin.
  @GET('/api/audit-log')
  Future<AuditLogEntryOutputPaginatedOutput> auditList({
    @Query('From') DateTime? from,
    @Query('To') DateTime? to,
    @Query('ActorId') String? actorId,
    @Query('Action') String? action,
    @Query('TargetId') String? targetId,
    @Query('Succeeded') bool? succeeded,
    @Query('PageNumber') int? pageNumber,
    @Query('PageSize') int? pageSize,
  });
}
