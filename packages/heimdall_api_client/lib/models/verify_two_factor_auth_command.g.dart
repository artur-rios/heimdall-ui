// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'verify_two_factor_auth_command.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

VerifyTwoFactorAuthCommand _$VerifyTwoFactorAuthCommandFromJson(
  Map<String, dynamic> json,
) => VerifyTwoFactorAuthCommand(
  challengeToken: json['challengeToken'] as String?,
  code: json['code'] as String?,
  recoveryCode: json['recoveryCode'] as String?,
);

Map<String, dynamic> _$VerifyTwoFactorAuthCommandToJson(
  VerifyTwoFactorAuthCommand instance,
) => <String, dynamic>{
  'challengeToken': instance.challengeToken,
  'code': instance.code,
  'recoveryCode': instance.recoveryCode,
};
