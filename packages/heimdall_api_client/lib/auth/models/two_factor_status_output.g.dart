// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'two_factor_status_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TwoFactorStatusOutput _$TwoFactorStatusOutputFromJson(
  Map<String, dynamic> json,
) {
  $checkKeys(
    json,
    allowedKeys: const [
      'isActive',
      'appEnabled',
      'emailEnabled',
      'remainingRecoveryCodes',
    ],
    disallowNullValues: const [
      'isActive',
      'appEnabled',
      'emailEnabled',
      'remainingRecoveryCodes',
    ],
  );
  return TwoFactorStatusOutput(
    isActive: json['isActive'] as bool?,
    appEnabled: json['appEnabled'] as bool?,
    emailEnabled: json['emailEnabled'] as bool?,
    remainingRecoveryCodes: TwoFactorStatusOutput._read_remainingRecoveryCodes(
      json['remainingRecoveryCodes'],
    ),
  );
}

Map<String, dynamic> _$TwoFactorStatusOutputToJson(
  TwoFactorStatusOutput instance,
) => <String, dynamic>{
  'isActive': ?instance.isActive,
  'appEnabled': ?instance.appEnabled,
  'emailEnabled': ?instance.emailEnabled,
  'remainingRecoveryCodes':
      ?TwoFactorStatusOutput._write_remainingRecoveryCodes(
        instance.remainingRecoveryCodes,
      ),
};
