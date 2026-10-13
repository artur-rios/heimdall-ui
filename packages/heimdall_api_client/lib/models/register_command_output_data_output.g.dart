// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'register_command_output_data_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RegisterCommandOutputDataOutput _$RegisterCommandOutputDataOutputFromJson(
  Map<String, dynamic> json,
) => RegisterCommandOutputDataOutput(
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

Map<String, dynamic> _$RegisterCommandOutputDataOutputToJson(
  RegisterCommandOutputDataOutput instance,
) => <String, dynamic>{
  'messages': instance.messages,
  'errors': instance.errors,
  'timestamp': instance.timestamp?.toIso8601String(),
  'success': instance.success,
  'data': instance.data,
};
