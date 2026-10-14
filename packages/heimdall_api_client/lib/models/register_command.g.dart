// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'register_command.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RegisterCommand _$RegisterCommandFromJson(Map<String, dynamic> json) =>
    RegisterCommand(
      name: json['name'] as String?,
      email: json['email'] as String?,
      password: json['password'] as String?,
      scopeId: json['scopeId'] as String?,
    );

Map<String, dynamic> _$RegisterCommandToJson(RegisterCommand instance) =>
    <String, dynamic>{
      'name': instance.name,
      'email': instance.email,
      'password': instance.password,
      'scopeId': instance.scopeId,
    };
