// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_scope_owner_command.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreateScopeOwnerCommand _$CreateScopeOwnerCommandFromJson(
  Map<String, dynamic> json,
) => CreateScopeOwnerCommand(
  name: json['name'] as String?,
  email: json['email'] as String?,
  password: json['password'] as String?,
);

Map<String, dynamic> _$CreateScopeOwnerCommandToJson(
  CreateScopeOwnerCommand instance,
) => <String, dynamic>{
  'name': instance.name,
  'email': instance.email,
  'password': instance.password,
};
