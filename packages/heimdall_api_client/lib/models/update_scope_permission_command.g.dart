// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'update_scope_permission_command.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UpdateScopePermissionCommand _$UpdateScopePermissionCommandFromJson(
  Map<String, dynamic> json,
) => UpdateScopePermissionCommand(
  name: json['name'] as String?,
  description: json['description'] as String?,
  includeAsJwtClaim: json['includeAsJwtClaim'] as bool?,
);

Map<String, dynamic> _$UpdateScopePermissionCommandToJson(
  UpdateScopePermissionCommand instance,
) => <String, dynamic>{
  'name': instance.name,
  'description': instance.description,
  'includeAsJwtClaim': instance.includeAsJwtClaim,
};
