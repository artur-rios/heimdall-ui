// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'scope_owner_invitation_output_paginated_output_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ScopeOwnerInvitationOutputPaginatedOutput$Response
_$ScopeOwnerInvitationOutputPaginatedOutput$ResponseFromJson(
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
  return ScopeOwnerInvitationOutputPaginatedOutput$Response(
    messages: (json['messages'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList(),
    errors: (json['errors'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList(),
    timestamp:
        ScopeOwnerInvitationOutputPaginatedOutput$Response._read_timestamp(
          json['timestamp'],
        ),
    success: json['success'] as bool?,
    data: (json['data'] as List<dynamic>?)
        ?.map(
          (e) => ScopeOwnerInvitationOutput.fromJson(e as Map<String, dynamic>),
        )
        .toList(),
    pageNumber:
        ScopeOwnerInvitationOutputPaginatedOutput$Response._read_pageNumber(
          json['pageNumber'],
        ),
    pageSize: ScopeOwnerInvitationOutputPaginatedOutput$Response._read_pageSize(
      json['pageSize'],
    ),
    totalItems:
        ScopeOwnerInvitationOutputPaginatedOutput$Response._read_totalItems(
          json['totalItems'],
        ),
    totalPages:
        ScopeOwnerInvitationOutputPaginatedOutput$Response._read_totalPages(
          json['totalPages'],
        ),
    nextPageToken: json['nextPageToken'] as String?,
    hasNextPage: json['hasNextPage'] as bool?,
  );
}

Map<String, dynamic> _$ScopeOwnerInvitationOutputPaginatedOutput$ResponseToJson(
  ScopeOwnerInvitationOutputPaginatedOutput$Response instance,
) => <String, dynamic>{
  'messages': ?instance.messages,
  'errors': ?instance.errors,
  'timestamp':
      ?ScopeOwnerInvitationOutputPaginatedOutput$Response._write_timestamp(
        instance.timestamp,
      ),
  'success': ?instance.success,
  'data': ?instance.data?.map((e) => e.toJson()).toList(),
  'pageNumber':
      ?ScopeOwnerInvitationOutputPaginatedOutput$Response._write_pageNumber(
        instance.pageNumber,
      ),
  'pageSize':
      ?ScopeOwnerInvitationOutputPaginatedOutput$Response._write_pageSize(
        instance.pageSize,
      ),
  'totalItems':
      ?ScopeOwnerInvitationOutputPaginatedOutput$Response._write_totalItems(
        instance.totalItems,
      ),
  'totalPages':
      ?ScopeOwnerInvitationOutputPaginatedOutput$Response._write_totalPages(
        instance.totalPages,
      ),
  'nextPageToken': ?instance.nextPageToken,
  'hasNextPage': ?instance.hasNextPage,
};
