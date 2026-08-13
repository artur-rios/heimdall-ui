// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'disable_two_factor_auth_command.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DisableTwoFactorAuthCommand _$DisableTwoFactorAuthCommandFromJson(
  Map<String, dynamic> json,
) => DisableTwoFactorAuthCommand(
  password: json['password'] as String?,
  code: json['code'] as String?,
  recoveryCode: json['recoveryCode'] as String?,
);

Map<String, dynamic> _$DisableTwoFactorAuthCommandToJson(
  DisableTwoFactorAuthCommand instance,
) => <String, dynamic>{
  'password': instance.password,
  'code': instance.code,
  'recoveryCode': instance.recoveryCode,
};
