// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'login_command_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LoginCommandOutput _$LoginCommandOutputFromJson(Map<String, dynamic> json) {
  $checkKeys(
    json,
    allowedKeys: const [
      'token',
      'expiresAt',
      'emailVerified',
      'requiresTwoFactor',
      'challengeToken',
      'availableMethods',
      'processingRestricted',
    ],
    disallowNullValues: const ['requiresTwoFactor', 'processingRestricted'],
  );
  return LoginCommandOutput(
    token: json['token'] as String?,
    expiresAt: LoginCommandOutput._read_expiresAt(json['expiresAt']),
    emailVerified: json['emailVerified'] as bool?,
    requiresTwoFactor: json['requiresTwoFactor'] as bool?,
    challengeToken: json['challengeToken'] as String?,
    availableMethods: (json['availableMethods'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList(),
    processingRestricted: json['processingRestricted'] as bool?,
  );
}

Map<String, dynamic> _$LoginCommandOutputToJson(LoginCommandOutput instance) =>
    <String, dynamic>{
      'token': ?instance.token,
      'expiresAt': ?LoginCommandOutput._write_expiresAt(instance.expiresAt),
      'emailVerified': ?instance.emailVerified,
      'requiresTwoFactor': ?instance.requiresTwoFactor,
      'challengeToken': ?instance.challengeToken,
      'availableMethods': ?instance.availableMethods,
      'processingRestricted': ?instance.processingRestricted,
    };
