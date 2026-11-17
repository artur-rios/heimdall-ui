// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'google_user_output_paginated_output_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GoogleUserOutputPaginatedOutput$Request
_$GoogleUserOutputPaginatedOutput$RequestFromJson(Map<String, dynamic> json) {
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
  return GoogleUserOutputPaginatedOutput$Request(
    messages: (json['messages'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList(),
    errors: (json['errors'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList(),
    timestamp: GoogleUserOutputPaginatedOutput$Request._read_timestamp(
      json['timestamp'],
    ),
    data: (json['data'] as List<dynamic>?)
        ?.map((e) => GoogleUserOutput.fromJson(e as Map<String, dynamic>))
        .toList(),
    pageNumber: GoogleUserOutputPaginatedOutput$Request._read_pageNumber(
      json['pageNumber'],
    ),
    pageSize: GoogleUserOutputPaginatedOutput$Request._read_pageSize(
      json['pageSize'],
    ),
    totalItems: GoogleUserOutputPaginatedOutput$Request._read_totalItems(
      json['totalItems'],
    ),
    nextPageToken: json['nextPageToken'] as String?,
  );
}

Map<String, dynamic> _$GoogleUserOutputPaginatedOutput$RequestToJson(
  GoogleUserOutputPaginatedOutput$Request instance,
) => <String, dynamic>{
  'messages': ?instance.messages,
  'errors': ?instance.errors,
  'timestamp': ?GoogleUserOutputPaginatedOutput$Request._write_timestamp(
    instance.timestamp,
  ),
  'data': ?instance.data?.map((e) => e.toJson()).toList(),
  'pageNumber': ?GoogleUserOutputPaginatedOutput$Request._write_pageNumber(
    instance.pageNumber,
  ),
  'pageSize': ?GoogleUserOutputPaginatedOutput$Request._write_pageSize(
    instance.pageSize,
  ),
  'totalItems': ?GoogleUserOutputPaginatedOutput$Request._write_totalItems(
    instance.totalItems,
  ),
  'nextPageToken': ?instance.nextPageToken,
};
