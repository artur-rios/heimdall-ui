// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_user_command.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreateUserCommand _$CreateUserCommandFromJson(Map<String, dynamic> json) =>
    CreateUserCommand(
      scopeId: json['scopeId'] as String?,
      name: json['name'] as String?,
      email: json['email'] as String?,
      password: json['password'] as String?,
      actingPersonId: json['actingPersonId'] as String?,
      actingRole: (json['actingRole'] as num?)?.toInt(),
    );

Map<String, dynamic> _$CreateUserCommandToJson(CreateUserCommand instance) =>
    <String, dynamic>{
      'scopeId': instance.scopeId,
      'name': instance.name,
      'email': instance.email,
      'password': instance.password,
      'actingPersonId': instance.actingPersonId,
      'actingRole': instance.actingRole,
    };
