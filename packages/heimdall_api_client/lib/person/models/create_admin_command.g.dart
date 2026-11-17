// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_admin_command.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreateAdminCommand _$CreateAdminCommandFromJson(Map<String, dynamic> json) {
  $checkKeys(
    json,
    allowedKeys: const ['name', 'email', 'password', 'role'],
    disallowNullValues: const ['role'],
  );
  return CreateAdminCommand(
    name: json['name'] as String?,
    email: json['email'] as String?,
    password: json['password'] as String?,
    role: CreateAdminCommand._read_role(json['role']),
  );
}

Map<String, dynamic> _$CreateAdminCommandToJson(CreateAdminCommand instance) =>
    <String, dynamic>{
      'name': ?instance.name,
      'email': ?instance.email,
      'password': ?instance.password,
      'role': ?CreateAdminCommand._write_role(instance.role),
    };
