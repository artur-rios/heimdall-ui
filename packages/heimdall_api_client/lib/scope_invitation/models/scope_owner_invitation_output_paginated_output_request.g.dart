// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'scope_owner_invitation_output_paginated_output_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ScopeOwnerInvitationOutputPaginatedOutput$Request
_$ScopeOwnerInvitationOutputPaginatedOutput$RequestFromJson(
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
  return ScopeOwnerInvitationOutputPaginatedOutput$Request(
    messages: (json['messages'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList(),
    errors: (json['errors'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList(),
    timestamp:
        ScopeOwnerInvitationOutputPaginatedOutput$Request._read_timestamp(
          json['timestamp'],
        ),
    data: (json['data'] as List<dynamic>?)
        ?.map(
          (e) => ScopeOwnerInvitationOutput.fromJson(e as Map<String, dynamic>),
        )
        .toList(),
    pageNumber:
        ScopeOwnerInvitationOutputPaginatedOutput$Request._read_pageNumber(
          json['pageNumber'],
        ),
    pageSize: ScopeOwnerInvitationOutputPaginatedOutput$Request._read_pageSize(
      json['pageSize'],
    ),
    totalItems:
        ScopeOwnerInvitationOutputPaginatedOutput$Request._read_totalItems(
          json['totalItems'],
        ),
    nextPageToken: json['nextPageToken'] as String?,
  );
}

Map<String, dynamic> _$ScopeOwnerInvitationOutputPaginatedOutput$RequestToJson(
  ScopeOwnerInvitationOutputPaginatedOutput$Request instance,
) => <String, dynamic>{
  'messages': ?instance.messages,
  'errors': ?instance.errors,
  'timestamp':
      ?ScopeOwnerInvitationOutputPaginatedOutput$Request._write_timestamp(
        instance.timestamp,
      ),
  'data': ?instance.data?.map((e) => e.toJson()).toList(),
  'pageNumber':
      ?ScopeOwnerInvitationOutputPaginatedOutput$Request._write_pageNumber(
        instance.pageNumber,
      ),
  'pageSize':
      ?ScopeOwnerInvitationOutputPaginatedOutput$Request._write_pageSize(
        instance.pageSize,
      ),
  'totalItems':
      ?ScopeOwnerInvitationOutputPaginatedOutput$Request._write_totalItems(
        instance.totalItems,
      ),
  'nextPageToken': ?instance.nextPageToken,
};
