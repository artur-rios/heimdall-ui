// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'application_output_paginated_output_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ApplicationOutputPaginatedOutput$Request
_$ApplicationOutputPaginatedOutput$RequestFromJson(Map<String, dynamic> json) {
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
  return ApplicationOutputPaginatedOutput$Request(
    messages: (json['messages'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList(),
    errors: (json['errors'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList(),
    timestamp: ApplicationOutputPaginatedOutput$Request._read_timestamp(
      json['timestamp'],
    ),
    data: (json['data'] as List<dynamic>?)
        ?.map((e) => ApplicationOutput.fromJson(e as Map<String, dynamic>))
        .toList(),
    pageNumber: ApplicationOutputPaginatedOutput$Request._read_pageNumber(
      json['pageNumber'],
    ),
    pageSize: ApplicationOutputPaginatedOutput$Request._read_pageSize(
      json['pageSize'],
    ),
    totalItems: ApplicationOutputPaginatedOutput$Request._read_totalItems(
      json['totalItems'],
    ),
    nextPageToken: json['nextPageToken'] as String?,
  );
}

Map<String, dynamic> _$ApplicationOutputPaginatedOutput$RequestToJson(
  ApplicationOutputPaginatedOutput$Request instance,
) => <String, dynamic>{
  'messages': ?instance.messages,
  'errors': ?instance.errors,
  'timestamp': ?ApplicationOutputPaginatedOutput$Request._write_timestamp(
    instance.timestamp,
  ),
  'data': ?instance.data?.map((e) => e.toJson()).toList(),
  'pageNumber': ?ApplicationOutputPaginatedOutput$Request._write_pageNumber(
    instance.pageNumber,
  ),
  'pageSize': ?ApplicationOutputPaginatedOutput$Request._write_pageSize(
    instance.pageSize,
  ),
  'totalItems': ?ApplicationOutputPaginatedOutput$Request._write_totalItems(
    instance.totalItems,
  ),
  'nextPageToken': ?instance.nextPageToken,
};
