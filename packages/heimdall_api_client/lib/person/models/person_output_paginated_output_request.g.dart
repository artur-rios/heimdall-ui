// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'person_output_paginated_output_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PersonOutputPaginatedOutput$Request
_$PersonOutputPaginatedOutput$RequestFromJson(Map<String, dynamic> json) {
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
  return PersonOutputPaginatedOutput$Request(
    messages: (json['messages'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList(),
    errors: (json['errors'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList(),
    timestamp: PersonOutputPaginatedOutput$Request._read_timestamp(
      json['timestamp'],
    ),
    data: (json['data'] as List<dynamic>?)
        ?.map((e) => PersonOutput.fromJson(e as Map<String, dynamic>))
        .toList(),
    pageNumber: PersonOutputPaginatedOutput$Request._read_pageNumber(
      json['pageNumber'],
    ),
    pageSize: PersonOutputPaginatedOutput$Request._read_pageSize(
      json['pageSize'],
    ),
    totalItems: PersonOutputPaginatedOutput$Request._read_totalItems(
      json['totalItems'],
    ),
    nextPageToken: json['nextPageToken'] as String?,
  );
}

Map<String, dynamic> _$PersonOutputPaginatedOutput$RequestToJson(
  PersonOutputPaginatedOutput$Request instance,
) => <String, dynamic>{
  'messages': ?instance.messages,
  'errors': ?instance.errors,
  'timestamp': ?PersonOutputPaginatedOutput$Request._write_timestamp(
    instance.timestamp,
  ),
  'data': ?instance.data?.map((e) => e.toJson()).toList(),
  'pageNumber': ?PersonOutputPaginatedOutput$Request._write_pageNumber(
    instance.pageNumber,
  ),
  'pageSize': ?PersonOutputPaginatedOutput$Request._write_pageSize(
    instance.pageSize,
  ),
  'totalItems': ?PersonOutputPaginatedOutput$Request._write_totalItems(
    instance.totalItems,
  ),
  'nextPageToken': ?instance.nextPageToken,
};
