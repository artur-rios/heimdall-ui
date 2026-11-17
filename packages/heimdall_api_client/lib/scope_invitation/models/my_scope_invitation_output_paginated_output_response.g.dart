// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'my_scope_invitation_output_paginated_output_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MyScopeInvitationOutputPaginatedOutput$Response
_$MyScopeInvitationOutputPaginatedOutput$ResponseFromJson(
  Map<String, dynamic> json,
) {
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
  return MyScopeInvitationOutputPaginatedOutput$Response(
    messages: (json['messages'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList(),
    errors: (json['errors'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList(),
    timestamp: MyScopeInvitationOutputPaginatedOutput$Response._read_timestamp(
      json['timestamp'],
    ),
    success: json['success'] as bool?,
    data: (json['data'] as List<dynamic>?)
        ?.map(
          (e) => MyScopeInvitationOutput.fromJson(e as Map<String, dynamic>),
        )
        .toList(),
    pageNumber:
        MyScopeInvitationOutputPaginatedOutput$Response._read_pageNumber(
          json['pageNumber'],
        ),
    pageSize: MyScopeInvitationOutputPaginatedOutput$Response._read_pageSize(
      json['pageSize'],
    ),
    totalItems:
        MyScopeInvitationOutputPaginatedOutput$Response._read_totalItems(
          json['totalItems'],
        ),
    totalPages:
        MyScopeInvitationOutputPaginatedOutput$Response._read_totalPages(
          json['totalPages'],
        ),
    nextPageToken: json['nextPageToken'] as String?,
    hasNextPage: json['hasNextPage'] as bool?,
  );
}

Map<String, dynamic> _$MyScopeInvitationOutputPaginatedOutput$ResponseToJson(
  MyScopeInvitationOutputPaginatedOutput$Response instance,
) => <String, dynamic>{
  'messages': ?instance.messages,
  'errors': ?instance.errors,
  'timestamp':
      ?MyScopeInvitationOutputPaginatedOutput$Response._write_timestamp(
        instance.timestamp,
      ),
  'success': ?instance.success,
  'data': ?instance.data?.map((e) => e.toJson()).toList(),
  'pageNumber':
      ?MyScopeInvitationOutputPaginatedOutput$Response._write_pageNumber(
        instance.pageNumber,
      ),
  'pageSize': ?MyScopeInvitationOutputPaginatedOutput$Response._write_pageSize(
    instance.pageSize,
  ),
  'totalItems':
      ?MyScopeInvitationOutputPaginatedOutput$Response._write_totalItems(
        instance.totalItems,
      ),
  'totalPages':
      ?MyScopeInvitationOutputPaginatedOutput$Response._write_totalPages(
        instance.totalPages,
      ),
  'nextPageToken': ?instance.nextPageToken,
  'hasNextPage': ?instance.hasNextPage,
};
