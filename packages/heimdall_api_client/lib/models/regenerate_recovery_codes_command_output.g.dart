// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'regenerate_recovery_codes_command_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RegenerateRecoveryCodesCommandOutput
_$RegenerateRecoveryCodesCommandOutputFromJson(Map<String, dynamic> json) =>
    RegenerateRecoveryCodesCommandOutput(
      recoveryCodes: (json['recoveryCodes'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
    );

Map<String, dynamic> _$RegenerateRecoveryCodesCommandOutputToJson(
  RegenerateRecoveryCodesCommandOutput instance,
) => <String, dynamic>{'recoveryCodes': instance.recoveryCodes};
