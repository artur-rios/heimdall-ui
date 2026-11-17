// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'audit_log_entry_output_paginated_output_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AuditLogEntryOutputPaginatedOutput$Request
_$AuditLogEntryOutputPaginatedOutput$RequestFromJson(
  Map<String, dynamic> json,
) {
  $checkKeys(
    json,
    allowedKeys: const [
      'messages',
      'errors',
      'timestamp',
      'data',
      'pageNumber',
      'pageSize',
      'totalItems',
      'nextPageToken',
    ],
    disallowNullValues: const [
      'timestamp',
      'pageNumber',
      'pageSize',
      'totalItems',
    ],
  );
  return AuditLogEntryOutputPaginatedOutput$Request(
    messages: (json['messages'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList(),
    errors: (json['errors'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList(),
    timestamp: AuditLogEntryOutputPaginatedOutput$Request._read_timestamp(
      json['timestamp'],
    ),
    data: (json['data'] as List<dynamic>?)
        ?.map((e) => AuditLogEntryOutput.fromJson(e as Map<String, dynamic>))
        .toList(),
    pageNumber: AuditLogEntryOutputPaginatedOutput$Request._read_pageNumber(
      json['pageNumber'],
    ),
    pageSize: AuditLogEntryOutputPaginatedOutput$Request._read_pageSize(
      json['pageSize'],
    ),
    totalItems: AuditLogEntryOutputPaginatedOutput$Request._read_totalItems(
      json['totalItems'],
    ),
    nextPageToken: json['nextPageToken'] as String?,
  );
}

Map<String, dynamic> _$AuditLogEntryOutputPaginatedOutput$RequestToJson(
  AuditLogEntryOutputPaginatedOutput$Request instance,
) => <String, dynamic>{
  'messages': ?instance.messages,
  'errors': ?instance.errors,
  'timestamp': ?AuditLogEntryOutputPaginatedOutput$Request._write_timestamp(
    instance.timestamp,
  ),
  'data': ?instance.data?.map((e) => e.toJson()).toList(),
  'pageNumber': ?AuditLogEntryOutputPaginatedOutput$Request._write_pageNumber(
    instance.pageNumber,
  ),
  'pageSize': ?AuditLogEntryOutputPaginatedOutput$Request._write_pageSize(
    instance.pageSize,
  ),
  'totalItems': ?AuditLogEntryOutputPaginatedOutput$Request._write_totalItems(
    instance.totalItems,
  ),
  'nextPageToken': ?instance.nextPageToken,
};
