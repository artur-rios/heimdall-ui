// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_user_command.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreateUserCommand _$CreateUserCommandFromJson(Map<String, dynamic> json) =>
    CreateUserCommand(
      name: json['name'] as String?,
      email: json['email'] as String?,
      password: json['password'] as String?,
    );

Map<String, dynamic> _$CreateUserCommandToJson(CreateUserCommand instance) =>
    <String, dynamic>{
      'name': instance.name,
      'email': instance.email,
      'password': instance.password,
    };
