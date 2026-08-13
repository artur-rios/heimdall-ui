// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'scope_permission_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ScopePermissionOutput _$ScopePermissionOutputFromJson(
  Map<String, dynamic> json,
) => ScopePermissionOutput(
  id: json['id'] as String?,
  name: json['name'] as String?,
  description: json['description'] as String?,
  includeAsJwtClaim: json['includeAsJwtClaim'] as bool?,
  scopeId: json['scopeId'] as String?,
  isDeleted: json['isDeleted'] as bool?,
  createdAt: json['createdAt'] == null
      ? null
      : DateTime.parse(json['createdAt'] as String),
  updatedAt: json['updatedAt'] == null
      ? null
      : DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$ScopePermissionOutputToJson(
  ScopePermissionOutput instance,
) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'description': instance.description,
  'includeAsJwtClaim': instance.includeAsJwtClaim,
  'scopeId': instance.scopeId,
  'isDeleted': instance.isDeleted,
  'createdAt': instance.createdAt?.toIso8601String(),
  'updatedAt': instance.updatedAt?.toIso8601String(),
};
