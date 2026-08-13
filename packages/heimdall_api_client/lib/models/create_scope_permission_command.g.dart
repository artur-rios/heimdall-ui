// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_scope_permission_command.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreateScopePermissionCommand _$CreateScopePermissionCommandFromJson(
  Map<String, dynamic> json,
) => CreateScopePermissionCommand(
  name: json['name'] as String?,
  description: json['description'] as String?,
  includeAsJwtClaim: json['includeAsJwtClaim'] as bool?,
);

Map<String, dynamic> _$CreateScopePermissionCommandToJson(
  CreateScopePermissionCommand instance,
) => <String, dynamic>{
  'name': instance.name,
  'description': instance.description,
  'includeAsJwtClaim': instance.includeAsJwtClaim,
};
