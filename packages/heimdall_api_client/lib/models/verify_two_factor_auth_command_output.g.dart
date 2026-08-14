// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'verify_two_factor_auth_command_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

VerifyTwoFactorAuthCommandOutput _$VerifyTwoFactorAuthCommandOutputFromJson(
  Map<String, dynamic> json,
) => VerifyTwoFactorAuthCommandOutput(
  token: json['token'] as String?,
  expiresAt: json['expiresAt'] == null
      ? null
      : DateTime.parse(json['expiresAt'] as String),
  emailVerified: json['emailVerified'] as bool?,
);

Map<String, dynamic> _$VerifyTwoFactorAuthCommandOutputToJson(
  VerifyTwoFactorAuthCommandOutput instance,
) => <String, dynamic>{
  'token': instance.token,
  'expiresAt': instance.expiresAt?.toIso8601String(),
  'emailVerified': instance.emailVerified,
};
