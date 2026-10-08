// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'request_erasure_command_output_data_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RequestErasureCommandOutputDataOutput
_$RequestErasureCommandOutputDataOutputFromJson(Map<String, dynamic> json) =>
    RequestErasureCommandOutputDataOutput(
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
      data: json['data'] == null
          ? null
          : RequestErasureCommandOutput.fromJson(
              json['data'] as Map<String, dynamic>,
            ),
    );

Map<String, dynamic> _$RequestErasureCommandOutputDataOutputToJson(
  RequestErasureCommandOutputDataOutput instance,
) => <String, dynamic>{
  'messages': instance.messages,
  'errors': instance.errors,
  'timestamp': instance.timestamp?.toIso8601String(),
  'success': instance.success,
  'data': instance.data,
};
