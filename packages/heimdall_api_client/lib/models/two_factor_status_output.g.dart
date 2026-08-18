// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'two_factor_status_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TwoFactorStatusOutput _$TwoFactorStatusOutputFromJson(
  Map<String, dynamic> json,
) => TwoFactorStatusOutput(
  isActive: json['isActive'] as bool?,
  appEnabled: json['appEnabled'] as bool?,
  emailEnabled: json['emailEnabled'] as bool?,
  remainingRecoveryCodes: (json['remainingRecoveryCodes'] as num?)?.toInt(),
);

Map<String, dynamic> _$TwoFactorStatusOutputToJson(
  TwoFactorStatusOutput instance,
) => <String, dynamic>{
  'isActive': instance.isActive,
  'appEnabled': instance.appEnabled,
  'emailEnabled': instance.emailEnabled,
  'remainingRecoveryCodes': instance.remainingRecoveryCodes,
};
