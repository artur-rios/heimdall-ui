// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'google_sign_out_command_output_data_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GoogleSignOutCommandOutputDataOutput
_$GoogleSignOutCommandOutputDataOutputFromJson(Map<String, dynamic> json) =>
    GoogleSignOutCommandOutputDataOutput(
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

Map<String, dynamic> _$GoogleSignOutCommandOutputDataOutputToJson(
  GoogleSignOutCommandOutputDataOutput instance,
) => <String, dynamic>{
  'messages': instance.messages,
  'errors': instance.errors,
  'timestamp': instance.timestamp?.toIso8601String(),
  'success': instance.success,
  'data': instance.data,
};
