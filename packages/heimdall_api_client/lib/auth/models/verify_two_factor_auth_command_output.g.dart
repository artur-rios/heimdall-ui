// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'verify_two_factor_auth_command_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

VerifyTwoFactorAuthCommandOutput _$VerifyTwoFactorAuthCommandOutputFromJson(
  Map<String, dynamic> json,
) {
  $checkKeys(
    json,
    allowedKeys: const [
      'token',
      'expiresAt',
      'emailVerified',
      'processingRestricted',
    ],
    disallowNullValues: const [
      'expiresAt',
      'emailVerified',
      'processingRestricted',
    ],
  );
  return VerifyTwoFactorAuthCommandOutput(
    token: json['token'] as String?,
    expiresAt: VerifyTwoFactorAuthCommandOutput._read_expiresAt(
      json['expiresAt'],
    ),
    emailVerified: json['emailVerified'] as bool?,
    processingRestricted: json['processingRestricted'] as bool?,
  );
}

Map<String, dynamic> _$VerifyTwoFactorAuthCommandOutputToJson(
  VerifyTwoFactorAuthCommandOutput instance,
) => <String, dynamic>{
  'token': ?instance.token,
  'expiresAt': ?VerifyTwoFactorAuthCommandOutput._write_expiresAt(
    instance.expiresAt,
  ),
  'emailVerified': ?instance.emailVerified,
  'processingRestricted': ?instance.processingRestricted,
};
