// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'confirm_two_factor_auth_command_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ConfirmTwoFactorAuthCommandOutput _$ConfirmTwoFactorAuthCommandOutputFromJson(
  Map<String, dynamic> json,
) => ConfirmTwoFactorAuthCommandOutput(
  enabled: json['enabled'] as bool?,
  recoveryCodes: (json['recoveryCodes'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
);

Map<String, dynamic> _$ConfirmTwoFactorAuthCommandOutputToJson(
  ConfirmTwoFactorAuthCommandOutput instance,
) => <String, dynamic>{
  'enabled': instance.enabled,
  'recoveryCodes': instance.recoveryCodes,
};
