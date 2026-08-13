// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_scope_permission_command_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreateScopePermissionCommandOutput _$CreateScopePermissionCommandOutputFromJson(
  Map<String, dynamic> json,
) => CreateScopePermissionCommandOutput(
  id: json['id'] as String?,
  name: json['name'] as String?,
  description: json['description'] as String?,
  includeAsJwtClaim: json['includeAsJwtClaim'] as bool?,
  scopeId: json['scopeId'] as String?,
  createdAt: json['createdAt'] == null
      ? null
      : DateTime.parse(json['createdAt'] as String),
);

Map<String, dynamic> _$CreateScopePermissionCommandOutputToJson(
  CreateScopePermissionCommandOutput instance,
) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'description': instance.description,
  'includeAsJwtClaim': instance.includeAsJwtClaim,
  'scopeId': instance.scopeId,
  'createdAt': instance.createdAt?.toIso8601String(),
};
