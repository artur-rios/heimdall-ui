// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_admin_command.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreateAdminCommand _$CreateAdminCommandFromJson(Map<String, dynamic> json) =>
    CreateAdminCommand(
      name: json['name'] as String?,
      email: json['email'] as String?,
      password: json['password'] as String?,
      role: (json['role'] as num?)?.toInt(),
    );

Map<String, dynamic> _$CreateAdminCommandToJson(CreateAdminCommand instance) =>
    <String, dynamic>{
      'name': instance.name,
      'email': instance.email,
      'password': instance.password,
      'role': instance.role,
    };
