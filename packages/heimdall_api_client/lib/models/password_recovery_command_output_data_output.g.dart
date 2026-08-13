// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'password_recovery_command_output_data_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PasswordRecoveryCommandOutputDataOutput
_$PasswordRecoveryCommandOutputDataOutputFromJson(Map<String, dynamic> json) =>
    PasswordRecoveryCommandOutputDataOutput(
      messages: (json['messages'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      errors: (json['errors'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      timestamp: json['timestamp'] == null
          ? null
          : DateTime.parse(json['timestamp'] as String),
      success: json['success'] as bool?,
      data: json['data'],
    );

Map<String, dynamic> _$PasswordRecoveryCommandOutputDataOutputToJson(
  PasswordRecoveryCommandOutputDataOutput instance,
) => <String, dynamic>{
  'messages': instance.messages,
  'errors': instance.errors,
  'timestamp': instance.timestamp?.toIso8601String(),
  'success': instance.success,
  'data': instance.data,
};
