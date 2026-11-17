// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'add_scope_owner_command_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AddScopeOwnerCommandOutput _$AddScopeOwnerCommandOutputFromJson(
  Map<String, dynamic> json,
) {
  $checkKeys(
    json,
    allowedKeys: const [
      'scopeId',
      'personId',
      'alreadyOwner',
      'invited',
      'invitationId',
      'invitationExpiresAt',
    ],
    disallowNullValues: const [
      'scopeId',
      'personId',
      'alreadyOwner',
      'invited',
    ],
  );
  return AddScopeOwnerCommandOutput(
    scopeId: json['scopeId'] as String?,
    personId: json['personId'] as String?,
    alreadyOwner: json['alreadyOwner'] as bool?,
    invited: json['invited'] as bool?,
    invitationId: json['invitationId'] as String?,
    invitationExpiresAt: AddScopeOwnerCommandOutput._read_invitationExpiresAt(
      json['invitationExpiresAt'],
    ),
  );
}

Map<String, dynamic> _$AddScopeOwnerCommandOutputToJson(
  AddScopeOwnerCommandOutput instance,
) => <String, dynamic>{
  'scopeId': ?instance.scopeId,
  'personId': ?instance.personId,
  'alreadyOwner': ?instance.alreadyOwner,
  'invited': ?instance.invited,
  'invitationId': ?instance.invitationId,
  'invitationExpiresAt': ?AddScopeOwnerCommandOutput._write_invitationExpiresAt(
    instance.invitationExpiresAt,
  ),
};
