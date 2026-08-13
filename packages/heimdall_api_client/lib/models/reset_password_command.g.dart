// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reset_password_command.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ResetPasswordCommand _$ResetPasswordCommandFromJson(
  Map<String, dynamic> json,
) => ResetPasswordCommand(
  token: json['token'] as String?,
  newPassword: json['newPassword'] as String?,
);

Map<String, dynamic> _$ResetPasswordCommandToJson(
  ResetPasswordCommand instance,
) => <String, dynamic>{
  'token': instance.token,
  'newPassword': instance.newPassword,
};
