// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'regenerate_recovery_codes_command_output_data_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RegenerateRecoveryCodesCommandOutputDataOutput
_$RegenerateRecoveryCodesCommandOutputDataOutputFromJson(
  Map<String, dynamic> json,
) => RegenerateRecoveryCodesCommandOutputDataOutput(
  messages: (json['messages'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  errors: (json['errors'] as List<dynamic>?)?.map((e) => e as String).toList(),
  timestamp: json['timestamp'] == null
      ? null
      : DateTime.parse(json['timestamp'] as String),
  success: json['success'] as bool?,
  data: json['data'] == null
      ? null
      : RegenerateRecoveryCodesCommandOutput.fromJson(
          json['data'] as Map<String, dynamic>,
        ),
);

Map<String, dynamic> _$RegenerateRecoveryCodesCommandOutputDataOutputToJson(
  RegenerateRecoveryCodesCommandOutputDataOutput instance,
) => <String, dynamic>{
  'messages': instance.messages,
  'errors': instance.errors,
  'timestamp': instance.timestamp?.toIso8601String(),
  'success': instance.success,
  'data': instance.data,
};
