// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'person_summary_output_paginated_output_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PersonSummaryOutputPaginatedOutput$Request
_$PersonSummaryOutputPaginatedOutput$RequestFromJson(
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
  return PersonSummaryOutputPaginatedOutput$Request(
    messages: (json['messages'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList(),
    errors: (json['errors'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList(),
    timestamp: PersonSummaryOutputPaginatedOutput$Request._read_timestamp(
      json['timestamp'],
    ),
    data: (json['data'] as List<dynamic>?)
        ?.map((e) => PersonSummaryOutput.fromJson(e as Map<String, dynamic>))
        .toList(),
    pageNumber: PersonSummaryOutputPaginatedOutput$Request._read_pageNumber(
      json['pageNumber'],
    ),
    pageSize: PersonSummaryOutputPaginatedOutput$Request._read_pageSize(
      json['pageSize'],
    ),
    totalItems: PersonSummaryOutputPaginatedOutput$Request._read_totalItems(
      json['totalItems'],
    ),
    nextPageToken: json['nextPageToken'] as String?,
  );
}

Map<String, dynamic> _$PersonSummaryOutputPaginatedOutput$RequestToJson(
  PersonSummaryOutputPaginatedOutput$Request instance,
) => <String, dynamic>{
  'messages': ?instance.messages,
  'errors': ?instance.errors,
  'timestamp': ?PersonSummaryOutputPaginatedOutput$Request._write_timestamp(
    instance.timestamp,
  ),
  'data': ?instance.data?.map((e) => e.toJson()).toList(),
  'pageNumber': ?PersonSummaryOutputPaginatedOutput$Request._write_pageNumber(
    instance.pageNumber,
  ),
  'pageSize': ?PersonSummaryOutputPaginatedOutput$Request._write_pageSize(
    instance.pageSize,
  ),
  'totalItems': ?PersonSummaryOutputPaginatedOutput$Request._write_totalItems(
    instance.totalItems,
  ),
  'nextPageToken': ?instance.nextPageToken,
};
