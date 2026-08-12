// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'update_scope_permission_command_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UpdateScopePermissionCommandOutput _$UpdateScopePermissionCommandOutputFromJson(
  Map<String, dynamic> json,
) => UpdateScopePermissionCommandOutput(
  id: json['id'] as String?,
  name: json['name'] as String?,
  description: json['description'] as String?,
  includeAsJwtClaim: json['includeAsJwtClaim'] as bool?,
  scopeId: json['scopeId'] as String?,
  createdAt: json['createdAt'] == null
      ? null
      : DateTime.parse(json['createdAt'] as String),
  updatedAt: json['updatedAt'] == null
      ? null
      : DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$UpdateScopePermissionCommandOutputToJson(
  UpdateScopePermissionCommandOutput instance,
) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'description': instance.description,
  'includeAsJwtClaim': instance.includeAsJwtClaim,
  'scopeId': instance.scopeId,
  'createdAt': instance.createdAt?.toIso8601String(),
  'updatedAt': instance.updatedAt?.toIso8601String(),
};
