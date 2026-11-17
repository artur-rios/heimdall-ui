// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'google_user_output_paginated_output_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GoogleUserOutputPaginatedOutput$Response
_$GoogleUserOutputPaginatedOutput$ResponseFromJson(Map<String, dynamic> json) {
  $checkKeys(
    json,
    allowedKeys: const [
      'messages',
      'errors',
      'timestamp',
      'success',
      'data',
      'pageNumber',
      'pageSize',
      'totalItems',
      'totalPages',
      'nextPageToken',
      'hasNextPage',
    ],
    disallowNullValues: const [
      'timestamp',
      'success',
      'pageNumber',
      'pageSize',
      'totalItems',
      'totalPages',
      'hasNextPage',
    ],
  );
  return GoogleUserOutputPaginatedOutput$Response(
    messages: (json['messages'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList(),
    errors: (json['errors'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList(),
    timestamp: GoogleUserOutputPaginatedOutput$Response._read_timestamp(
      json['timestamp'],
    ),
    success: json['success'] as bool?,
    data: (json['data'] as List<dynamic>?)
        ?.map((e) => GoogleUserOutput.fromJson(e as Map<String, dynamic>))
        .toList(),
    pageNumber: GoogleUserOutputPaginatedOutput$Response._read_pageNumber(
      json['pageNumber'],
    ),
    pageSize: GoogleUserOutputPaginatedOutput$Response._read_pageSize(
      json['pageSize'],
    ),
    totalItems: GoogleUserOutputPaginatedOutput$Response._read_totalItems(
      json['totalItems'],
    ),
    totalPages: GoogleUserOutputPaginatedOutput$Response._read_totalPages(
      json['totalPages'],
    ),
    nextPageToken: json['nextPageToken'] as String?,
    hasNextPage: json['hasNextPage'] as bool?,
  );
}

Map<String, dynamic> _$GoogleUserOutputPaginatedOutput$ResponseToJson(
  GoogleUserOutputPaginatedOutput$Response instance,
) => <String, dynamic>{
  'messages': ?instance.messages,
  'errors': ?instance.errors,
  'timestamp': ?GoogleUserOutputPaginatedOutput$Response._write_timestamp(
    instance.timestamp,
  ),
  'success': ?instance.success,
  'data': ?instance.data?.map((e) => e.toJson()).toList(),
  'pageNumber': ?GoogleUserOutputPaginatedOutput$Response._write_pageNumber(
    instance.pageNumber,
  ),
  'pageSize': ?GoogleUserOutputPaginatedOutput$Response._write_pageSize(
    instance.pageSize,
  ),
  'totalItems': ?GoogleUserOutputPaginatedOutput$Response._write_totalItems(
    instance.totalItems,
  ),
  'totalPages': ?GoogleUserOutputPaginatedOutput$Response._write_totalPages(
    instance.totalPages,
  ),
  'nextPageToken': ?instance.nextPageToken,
  'hasNextPage': ?instance.hasNextPage,
};
