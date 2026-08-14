// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'google_sign_in_command_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GoogleSignInCommandOutput _$GoogleSignInCommandOutputFromJson(
  Map<String, dynamic> json,
) => GoogleSignInCommandOutput(
  token: json['token'] as String?,
  expiresAt: json['expiresAt'] == null
      ? null
      : DateTime.parse(json['expiresAt'] as String),
  emailVerified: json['emailVerified'] as bool?,
);

Map<String, dynamic> _$GoogleSignInCommandOutputToJson(
  GoogleSignInCommandOutput instance,
) => <String, dynamic>{
  'token': instance.token,
  'expiresAt': instance.expiresAt?.toIso8601String(),
  'emailVerified': instance.emailVerified,
};
