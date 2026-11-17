// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'accept_scope_owner_invitation_command_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AcceptScopeOwnerInvitationCommandOutput
_$AcceptScopeOwnerInvitationCommandOutputFromJson(Map<String, dynamic> json) {
  $checkKeys(
    json,
    allowedKeys: const ['id', 'scopeId'],
    disallowNullValues: const ['id', 'scopeId'],
  );
  return AcceptScopeOwnerInvitationCommandOutput(
    id: json['id'] as String?,
    scopeId: json['scopeId'] as String?,
  );
}

Map<String, dynamic> _$AcceptScopeOwnerInvitationCommandOutputToJson(
  AcceptScopeOwnerInvitationCommandOutput instance,
) => <String, dynamic>{'id': ?instance.id, 'scopeId': ?instance.scopeId};
