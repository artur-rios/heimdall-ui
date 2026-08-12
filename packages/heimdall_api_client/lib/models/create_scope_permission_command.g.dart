// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_scope_permission_command.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreateScopePermissionCommand _$CreateScopePermissionCommandFromJson(
  Map<String, dynamic> json,
) => CreateScopePermissionCommand(
  scopeId: json['scopeId'] as String?,
  name: json['name'] as String?,
  description: json['description'] as String?,
  includeAsJwtClaim: json['includeAsJwtClaim'] as bool?,
  actingPersonId: json['actingPersonId'] as String?,
  actingRole: (json['actingRole'] as num?)?.toInt(),
);

Map<String, dynamic> _$CreateScopePermissionCommandToJson(
  CreateScopePermissionCommand instance,
) => <String, dynamic>{
  'scopeId': instance.scopeId,
  'name': instance.name,
  'description': instance.description,
  'includeAsJwtClaim': instance.includeAsJwtClaim,
  'actingPersonId': instance.actingPersonId,
  'actingRole': instance.actingRole,
};
