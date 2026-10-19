// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'my_scope_invitation_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MyScopeInvitationOutput _$MyScopeInvitationOutputFromJson(
  Map<String, dynamic> json,
) => MyScopeInvitationOutput(
  id: json['id'] as String?,
  scopeId: json['scopeId'] as String?,
  scopeName: json['scopeName'] as String?,
  invitedByName: json['invitedByName'] as String?,
  createdAt: json['createdAt'] == null
      ? null
      : DateTime.parse(json['createdAt'] as String),
  expiresAt: json['expiresAt'] == null
      ? null
      : DateTime.parse(json['expiresAt'] as String),
);

Map<String, dynamic> _$MyScopeInvitationOutputToJson(
  MyScopeInvitationOutput instance,
) => <String, dynamic>{
  'id': instance.id,
  'scopeId': instance.scopeId,
  'scopeName': instance.scopeName,
  'invitedByName': instance.invitedByName,
  'createdAt': instance.createdAt?.toIso8601String(),
  'expiresAt': instance.expiresAt?.toIso8601String(),
};
