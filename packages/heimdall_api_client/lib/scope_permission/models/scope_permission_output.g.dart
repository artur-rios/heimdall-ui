// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'scope_permission_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ScopePermissionOutput _$ScopePermissionOutputFromJson(
  Map<String, dynamic> json,
) {
  $checkKeys(
    json,
    allowedKeys: const [
      'id',
      'name',
      'description',
      'includeAsJwtClaim',
      'scopeId',
      'isDeleted',
      'createdAt',
      'updatedAt',
    ],
    disallowNullValues: const [
      'id',
      'includeAsJwtClaim',
      'scopeId',
      'isDeleted',
      'createdAt',
      'updatedAt',
    ],
  );
  return ScopePermissionOutput(
    id: json['id'] as String?,
    name: json['name'] as String?,
    description: json['description'] as String?,
    includeAsJwtClaim: json['includeAsJwtClaim'] as bool?,
    scopeId: json['scopeId'] as String?,
    isDeleted: json['isDeleted'] as bool?,
    createdAt: ScopePermissionOutput._read_createdAt(json['createdAt']),
    updatedAt: ScopePermissionOutput._read_updatedAt(json['updatedAt']),
  );
}

Map<String, dynamic> _$ScopePermissionOutputToJson(
  ScopePermissionOutput instance,
) => <String, dynamic>{
  'id': ?instance.id,
  'name': ?instance.name,
  'description': ?instance.description,
  'includeAsJwtClaim': ?instance.includeAsJwtClaim,
  'scopeId': ?instance.scopeId,
  'isDeleted': ?instance.isDeleted,
  'createdAt': ?ScopePermissionOutput._write_createdAt(instance.createdAt),
  'updatedAt': ?ScopePermissionOutput._write_updatedAt(instance.updatedAt),
};
