// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hard_delete_scope_command_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

HardDeleteScopeCommandOutput _$HardDeleteScopeCommandOutputFromJson(
  Map<String, dynamic> json,
) => HardDeleteScopeCommandOutput(
  id: json['id'] as String?,
  userCount: (json['userCount'] as num?)?.toInt(),
  googleUserCount: (json['googleUserCount'] as num?)?.toInt(),
  applicationCount: (json['applicationCount'] as num?)?.toInt(),
  scopePermissionCount: (json['scopePermissionCount'] as num?)?.toInt(),
);

Map<String, dynamic> _$HardDeleteScopeCommandOutputToJson(
  HardDeleteScopeCommandOutput instance,
) => <String, dynamic>{
  'id': instance.id,
  'userCount': instance.userCount,
  'googleUserCount': instance.googleUserCount,
  'applicationCount': instance.applicationCount,
  'scopePermissionCount': instance.scopePermissionCount,
};
