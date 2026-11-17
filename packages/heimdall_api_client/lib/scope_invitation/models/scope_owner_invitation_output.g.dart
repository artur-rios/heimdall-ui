// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'scope_owner_invitation_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ScopeOwnerInvitationOutput _$ScopeOwnerInvitationOutputFromJson(
  Map<String, dynamic> json,
) {
  $checkKeys(
    json,
    allowedKeys: const [
      'id',
      'inviteeId',
      'inviteeName',
      'inviteeEmail',
      'invitedByName',
      'createdAt',
      'expiresAt',
    ],
    disallowNullValues: const ['id', 'inviteeId', 'createdAt', 'expiresAt'],
  );
  return ScopeOwnerInvitationOutput(
    id: json['id'] as String?,
    inviteeId: json['inviteeId'] as String?,
    inviteeName: json['inviteeName'] as String?,
    inviteeEmail: json['inviteeEmail'] as String?,
    invitedByName: json['invitedByName'] as String?,
    createdAt: ScopeOwnerInvitationOutput._read_createdAt(json['createdAt']),
    expiresAt: ScopeOwnerInvitationOutput._read_expiresAt(json['expiresAt']),
  );
}

Map<String, dynamic> _$ScopeOwnerInvitationOutputToJson(
  ScopeOwnerInvitationOutput instance,
) => <String, dynamic>{
  'id': ?instance.id,
  'inviteeId': ?instance.inviteeId,
  'inviteeName': ?instance.inviteeName,
  'inviteeEmail': ?instance.inviteeEmail,
  'invitedByName': ?instance.invitedByName,
  'createdAt': ?ScopeOwnerInvitationOutput._write_createdAt(instance.createdAt),
  'expiresAt': ?ScopeOwnerInvitationOutput._write_expiresAt(instance.expiresAt),
};
