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
);

Map<String, dynamic> _$AddScopeOwnerCommandOutputToJson(
  AddScopeOwnerCommandOutput instance,
) => <String, dynamic>{
  'scopeId': instance.scopeId,
  'personId': instance.personId,
  'alreadyOwner': instance.alreadyOwner,
};
