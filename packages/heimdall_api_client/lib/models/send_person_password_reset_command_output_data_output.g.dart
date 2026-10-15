// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'send_person_password_reset_command_output_data_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SendPersonPasswordResetCommandOutputDataOutput
_$SendPersonPasswordResetCommandOutputDataOutputFromJson(
  Map<String, dynamic> json,
) => SendPersonPasswordResetCommandOutputDataOutput(
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
      : SendPersonPasswordResetCommandOutput.fromJson(
          json['data'] as Map<String, dynamic>,
        ),
);

Map<String, dynamic> _$SendPersonPasswordResetCommandOutputDataOutputToJson(
  SendPersonPasswordResetCommandOutputDataOutput instance,
) => <String, dynamic>{
  'messages': instance.messages,
  'errors': instance.errors,
  'timestamp': instance.timestamp?.toIso8601String(),
  'success': instance.success,
  'data': instance.data,
};
