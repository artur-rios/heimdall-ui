// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'my_scope_invitation_output_paginated_output_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MyScopeInvitationOutputPaginatedOutput$Request
_$MyScopeInvitationOutputPaginatedOutput$RequestFromJson(
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
  return MyScopeInvitationOutputPaginatedOutput$Request(
    messages: (json['messages'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList(),
    errors: (json['errors'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList(),
    timestamp: MyScopeInvitationOutputPaginatedOutput$Request._read_timestamp(
      json['timestamp'],
    ),
    data: (json['data'] as List<dynamic>?)
        ?.map(
          (e) => MyScopeInvitationOutput.fromJson(e as Map<String, dynamic>),
        )
        .toList(),
    pageNumber: MyScopeInvitationOutputPaginatedOutput$Request._read_pageNumber(
      json['pageNumber'],
    ),
    pageSize: MyScopeInvitationOutputPaginatedOutput$Request._read_pageSize(
      json['pageSize'],
    ),
    totalItems: MyScopeInvitationOutputPaginatedOutput$Request._read_totalItems(
      json['totalItems'],
    ),
    nextPageToken: json['nextPageToken'] as String?,
  );
}

Map<String, dynamic> _$MyScopeInvitationOutputPaginatedOutput$RequestToJson(
  MyScopeInvitationOutputPaginatedOutput$Request instance,
) => <String, dynamic>{
  'messages': ?instance.messages,
  'errors': ?instance.errors,
  'timestamp': ?MyScopeInvitationOutputPaginatedOutput$Request._write_timestamp(
    instance.timestamp,
  ),
  'data': ?instance.data?.map((e) => e.toJson()).toList(),
  'pageNumber':
      ?MyScopeInvitationOutputPaginatedOutput$Request._write_pageNumber(
        instance.pageNumber,
      ),
  'pageSize': ?MyScopeInvitationOutputPaginatedOutput$Request._write_pageSize(
    instance.pageSize,
  ),
  'totalItems':
      ?MyScopeInvitationOutputPaginatedOutput$Request._write_totalItems(
        instance.totalItems,
      ),
  'nextPageToken': ?instance.nextPageToken,
};
