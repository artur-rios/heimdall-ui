// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'update_scope_permission_command_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UpdateScopePermissionCommandOutput _$UpdateScopePermissionCommandOutputFromJson(
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
      'createdAt',
      'updatedAt',
    ],
    disallowNullValues: const [
      'id',
      'includeAsJwtClaim',
      'scopeId',
      'createdAt',
      'updatedAt',
    ],
  );
  return UpdateScopePermissionCommandOutput(
    id: json['id'] as String?,
    name: json['name'] as String?,
    description: json['description'] as String?,
    includeAsJwtClaim: json['includeAsJwtClaim'] as bool?,
    scopeId: json['scopeId'] as String?,
    createdAt: UpdateScopePermissionCommandOutput._read_createdAt(
      json['createdAt'],
    ),
    updatedAt: UpdateScopePermissionCommandOutput._read_updatedAt(
      json['updatedAt'],
    ),
  );
}

Map<String, dynamic> _$UpdateScopePermissionCommandOutputToJson(
  UpdateScopePermissionCommandOutput instance,
) => <String, dynamic>{
  'id': ?instance.id,
  'name': ?instance.name,
  'description': ?instance.description,
  'includeAsJwtClaim': ?instance.includeAsJwtClaim,
  'scopeId': ?instance.scopeId,
  'createdAt': ?UpdateScopePermissionCommandOutput._write_createdAt(
    instance.createdAt,
  ),
  'updatedAt': ?UpdateScopePermissionCommandOutput._write_updatedAt(
    instance.updatedAt,
  ),
};
