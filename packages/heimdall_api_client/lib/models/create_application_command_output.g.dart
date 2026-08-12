// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_application_command_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreateApplicationCommandOutput _$CreateApplicationCommandOutputFromJson(
  Map<String, dynamic> json,
) => CreateApplicationCommandOutput(
  id: json['id'] as String?,
  name: json['name'] as String?,
  scopeId: json['scopeId'] as String?,
  ownerId: json['ownerId'] as String?,
  createdAt: json['createdAt'] == null
      ? null
      : DateTime.parse(json['createdAt'] as String),
);

Map<String, dynamic> _$CreateApplicationCommandOutputToJson(
  CreateApplicationCommandOutput instance,
) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'scopeId': instance.scopeId,
  'ownerId': instance.ownerId,
  'createdAt': instance.createdAt?.toIso8601String(),
};
