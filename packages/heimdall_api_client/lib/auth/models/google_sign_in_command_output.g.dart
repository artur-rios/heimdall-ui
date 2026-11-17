// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'google_sign_in_command_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GoogleSignInCommandOutput _$GoogleSignInCommandOutputFromJson(
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
  return GoogleSignInCommandOutput(
    token: json['token'] as String?,
    expiresAt: GoogleSignInCommandOutput._read_expiresAt(json['expiresAt']),
    emailVerified: json['emailVerified'] as bool?,
    processingRestricted: json['processingRestricted'] as bool?,
  );
}

Map<String, dynamic> _$GoogleSignInCommandOutputToJson(
  GoogleSignInCommandOutput instance,
) => <String, dynamic>{
  'token': ?instance.token,
  'expiresAt': ?GoogleSignInCommandOutput._write_expiresAt(instance.expiresAt),
  'emailVerified': ?instance.emailVerified,
  'processingRestricted': ?instance.processingRestricted,
};
