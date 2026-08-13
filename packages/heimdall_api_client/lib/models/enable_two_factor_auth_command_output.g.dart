// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'enable_two_factor_auth_command_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

EnableTwoFactorAuthCommandOutput _$EnableTwoFactorAuthCommandOutputFromJson(
  Map<String, dynamic> json,
) => EnableTwoFactorAuthCommandOutput(
  otpAuthUri: json['otpAuthUri'] as String?,
  emailCodeSent: json['emailCodeSent'] as bool?,
);

Map<String, dynamic> _$EnableTwoFactorAuthCommandOutputToJson(
  EnableTwoFactorAuthCommandOutput instance,
) => <String, dynamic>{
  'otpAuthUri': instance.otpAuthUri,
  'emailCodeSent': instance.emailCodeSent,
};
