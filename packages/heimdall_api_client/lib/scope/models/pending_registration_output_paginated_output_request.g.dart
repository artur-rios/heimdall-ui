// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pending_registration_output_paginated_output_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PendingRegistrationOutputPaginatedOutput$Request
_$PendingRegistrationOutputPaginatedOutput$RequestFromJson(
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
  return PendingRegistrationOutputPaginatedOutput$Request(
    messages: (json['messages'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList(),
    errors: (json['errors'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList(),
    timestamp: PendingRegistrationOutputPaginatedOutput$Request._read_timestamp(
      json['timestamp'],
    ),
    data: (json['data'] as List<dynamic>?)
        ?.map(
          (e) => PendingRegistrationOutput.fromJson(e as Map<String, dynamic>),
        )
        .toList(),
    pageNumber:
        PendingRegistrationOutputPaginatedOutput$Request._read_pageNumber(
          json['pageNumber'],
        ),
    pageSize: PendingRegistrationOutputPaginatedOutput$Request._read_pageSize(
      json['pageSize'],
    ),
    totalItems:
        PendingRegistrationOutputPaginatedOutput$Request._read_totalItems(
          json['totalItems'],
        ),
    nextPageToken: json['nextPageToken'] as String?,
  );
}

Map<String, dynamic> _$PendingRegistrationOutputPaginatedOutput$RequestToJson(
  PendingRegistrationOutputPaginatedOutput$Request instance,
) => <String, dynamic>{
  'messages': ?instance.messages,
  'errors': ?instance.errors,
  'timestamp':
      ?PendingRegistrationOutputPaginatedOutput$Request._write_timestamp(
        instance.timestamp,
      ),
  'data': ?instance.data?.map((e) => e.toJson()).toList(),
  'pageNumber':
      ?PendingRegistrationOutputPaginatedOutput$Request._write_pageNumber(
        instance.pageNumber,
      ),
  'pageSize': ?PendingRegistrationOutputPaginatedOutput$Request._write_pageSize(
    instance.pageSize,
  ),
  'totalItems':
      ?PendingRegistrationOutputPaginatedOutput$Request._write_totalItems(
        instance.totalItems,
      ),
  'nextPageToken': ?instance.nextPageToken,
};
