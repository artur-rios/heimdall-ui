// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'scope_owner_invitation_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ScopeOwnerInvitationOutput _$ScopeOwnerInvitationOutputFromJson(
  Map<String, dynamic> json,
) => ScopeOwnerInvitationOutput(
  id: json['id'] as String?,
  inviteeId: json['inviteeId'] as String?,
  inviteeName: json['inviteeName'] as String?,
  inviteeEmail: json['inviteeEmail'] as String?,
  invitedByName: json['invitedByName'] as String?,
  createdAt: json['createdAt'] == null
      ? null
      : DateTime.parse(json['createdAt'] as String),
  expiresAt: json['expiresAt'] == null
      ? null
      : DateTime.parse(json['expiresAt'] as String),
);

Map<String, dynamic> _$ScopeOwnerInvitationOutputToJson(
  ScopeOwnerInvitationOutput instance,
) => <String, dynamic>{
  'id': instance.id,
  'inviteeId': instance.inviteeId,
  'inviteeName': instance.inviteeName,
  'inviteeEmail': instance.inviteeEmail,
  'invitedByName': instance.invitedByName,
  'createdAt': instance.createdAt?.toIso8601String(),
  'expiresAt': instance.expiresAt?.toIso8601String(),
};
