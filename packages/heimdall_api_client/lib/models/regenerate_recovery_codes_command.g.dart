// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'regenerate_recovery_codes_command.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RegenerateRecoveryCodesCommand _$RegenerateRecoveryCodesCommandFromJson(
  Map<String, dynamic> json,
) => RegenerateRecoveryCodesCommand(
  code: json['code'] as String?,
  recoveryCode: json['recoveryCode'] as String?,
);

Map<String, dynamic> _$RegenerateRecoveryCodesCommandToJson(
  RegenerateRecoveryCodesCommand instance,
) => <String, dynamic>{
  'code': instance.code,
  'recoveryCode': instance.recoveryCode,
};
