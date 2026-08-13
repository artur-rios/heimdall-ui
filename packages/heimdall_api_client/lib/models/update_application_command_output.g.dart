// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'update_application_command_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UpdateApplicationCommandOutput _$UpdateApplicationCommandOutputFromJson(
  Map<String, dynamic> json,
) => UpdateApplicationCommandOutput(
  id: json['id'] as String?,
  name: json['name'] as String?,
  scopeId: json['scopeId'] as String?,
  ownerId: json['ownerId'] as String?,
  createdAt: json['createdAt'] == null
      ? null
      : DateTime.parse(json['createdAt'] as String),
  updatedAt: json['updatedAt'] == null
      ? null
      : DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$UpdateApplicationCommandOutputToJson(
  UpdateApplicationCommandOutput instance,
) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'scopeId': instance.scopeId,
  'ownerId': instance.ownerId,
  'createdAt': instance.createdAt?.toIso8601String(),
  'updatedAt': instance.updatedAt?.toIso8601String(),
};
