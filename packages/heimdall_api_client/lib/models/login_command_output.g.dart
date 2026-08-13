// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'login_command_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LoginCommandOutput _$LoginCommandOutputFromJson(Map<String, dynamic> json) =>
    LoginCommandOutput(
      token: json['token'] as String?,
      expiresAt: json['expiresAt'] == null
          ? null
          : DateTime.parse(json['expiresAt'] as String),
      requiresTwoFactor: json['requiresTwoFactor'] as bool?,
      challengeToken: json['challengeToken'] as String?,
      availableMethods: (json['availableMethods'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
    );

Map<String, dynamic> _$LoginCommandOutputToJson(LoginCommandOutput instance) =>
    <String, dynamic>{
      'token': instance.token,
      'expiresAt': instance.expiresAt?.toIso8601String(),
      'requiresTwoFactor': instance.requiresTwoFactor,
      'challengeToken': instance.challengeToken,
      'availableMethods': instance.availableMethods,
    };
