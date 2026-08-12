// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'update_scope_permission_command.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UpdateScopePermissionCommand _$UpdateScopePermissionCommandFromJson(
  Map<String, dynamic> json,
) => UpdateScopePermissionCommand(
  scopeId: json['scopeId'] as String?,
  id: json['id'] as String?,
  name: json['name'] as String?,
  description: json['description'] as String?,
  includeAsJwtClaim: json['includeAsJwtClaim'] as bool?,
  actingPersonId: json['actingPersonId'] as String?,
  actingRole: (json['actingRole'] as num?)?.toInt(),
);

Map<String, dynamic> _$UpdateScopePermissionCommandToJson(
  UpdateScopePermissionCommand instance,
) => <String, dynamic>{
  'scopeId': instance.scopeId,
  'id': instance.id,
  'name': instance.name,
  'description': instance.description,
  'includeAsJwtClaim': instance.includeAsJwtClaim,
  'actingPersonId': instance.actingPersonId,
  'actingRole': instance.actingRole,
};
