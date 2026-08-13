// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'verify_email_command_output_data_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

VerifyEmailCommandOutputDataOutput _$VerifyEmailCommandOutputDataOutputFromJson(
  Map<String, dynamic> json,
) => VerifyEmailCommandOutputDataOutput(
  messages: (json['messages'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  errors: (json['errors'] as List<dynamic>?)?.map((e) => e as String).toList(),
  timestamp: json['timestamp'] == null
      ? null
      : DateTime.parse(json['timestamp'] as String),
  success: json['success'] as bool?,
  data: json['data'],
);

Map<String, dynamic> _$VerifyEmailCommandOutputDataOutputToJson(
  VerifyEmailCommandOutputDataOutput instance,
) => <String, dynamic>{
  'messages': instance.messages,
  'errors': instance.errors,
  'timestamp': instance.timestamp?.toIso8601String(),
  'success': instance.success,
  'data': instance.data,
};
