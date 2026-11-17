// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'my_scope_invitation_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MyScopeInvitationOutput _$MyScopeInvitationOutputFromJson(
  Map<String, dynamic> json,
) {
  $checkKeys(
    json,
    allowedKeys: const [
      'id',
      'scopeId',
      'scopeName',
      'invitedByName',
      'createdAt',
      'expiresAt',
    ],
    disallowNullValues: const ['id', 'scopeId', 'createdAt', 'expiresAt'],
  );
  return MyScopeInvitationOutput(
    id: json['id'] as String?,
    scopeId: json['scopeId'] as String?,
    scopeName: json['scopeName'] as String?,
    invitedByName: json['invitedByName'] as String?,
    createdAt: MyScopeInvitationOutput._read_createdAt(json['createdAt']),
    expiresAt: MyScopeInvitationOutput._read_expiresAt(json['expiresAt']),
  );
}

Map<String, dynamic> _$MyScopeInvitationOutputToJson(
  MyScopeInvitationOutput instance,
) => <String, dynamic>{
  'id': ?instance.id,
  'scopeId': ?instance.scopeId,
  'scopeName': ?instance.scopeName,
  'invitedByName': ?instance.invitedByName,
  'createdAt': ?MyScopeInvitationOutput._write_createdAt(instance.createdAt),
  'expiresAt': ?MyScopeInvitationOutput._write_expiresAt(instance.expiresAt),
};
