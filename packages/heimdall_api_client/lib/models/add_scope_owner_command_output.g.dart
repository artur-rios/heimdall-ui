// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'add_scope_owner_command_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AddScopeOwnerCommandOutput _$AddScopeOwnerCommandOutputFromJson(
  Map<String, dynamic> json,
) => AddScopeOwnerCommandOutput(
  scopeId: json['scopeId'] as String?,
  personId: json['personId'] as String?,
  alreadyOwner: json['alreadyOwner'] as bool?,
  invited: json['invited'] as bool?,
  invitationId: json['invitationId'] as String?,
  invitationExpiresAt: json['invitationExpiresAt'] == null
      ? null
      : DateTime.parse(json['invitationExpiresAt'] as String),
);

Map<String, dynamic> _$AddScopeOwnerCommandOutputToJson(
  AddScopeOwnerCommandOutput instance,
) => <String, dynamic>{
  'scopeId': instance.scopeId,
  'personId': instance.personId,
  'alreadyOwner': instance.alreadyOwner,
  'invited': instance.invited,
  'invitationId': instance.invitationId,
  'invitationExpiresAt': instance.invitationExpiresAt?.toIso8601String(),
};
