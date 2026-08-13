// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'delete_scope_command_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DeleteScopeCommandOutput _$DeleteScopeCommandOutputFromJson(
  Map<String, dynamic> json,
) => DeleteScopeCommandOutput(
  id: json['id'] as String?,
  userCount: (json['userCount'] as num?)?.toInt(),
  googleUserCount: (json['googleUserCount'] as num?)?.toInt(),
  applicationCount: (json['applicationCount'] as num?)?.toInt(),
);

Map<String, dynamic> _$DeleteScopeCommandOutputToJson(
  DeleteScopeCommandOutput instance,
) => <String, dynamic>{
  'id': instance.id,
  'userCount': instance.userCount,
  'googleUserCount': instance.googleUserCount,
  'applicationCount': instance.applicationCount,
};
