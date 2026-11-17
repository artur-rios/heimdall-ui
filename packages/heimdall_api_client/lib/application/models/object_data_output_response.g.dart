// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'object_data_output_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ObjectDataOutput$Response _$ObjectDataOutput$ResponseFromJson(
  Map<String, dynamic> json,
) {
  $checkKeys(
    json,
    allowedKeys: const ['messages', 'errors', 'timestamp', 'success', 'data'],
    disallowNullValues: const ['timestamp', 'success'],
  );
  return ObjectDataOutput$Response(
    messages: (json['messages'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList(),
    errors: (json['errors'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList(),
    timestamp: ObjectDataOutput$Response._read_timestamp(json['timestamp']),
    success: json['success'] as bool?,
    data: json['data'],
  );
}

Map<String, dynamic> _$ObjectDataOutput$ResponseToJson(
  ObjectDataOutput$Response instance,
) => <String, dynamic>{
  'messages': ?instance.messages,
  'errors': ?instance.errors,
  'timestamp': ?ObjectDataOutput$Response._write_timestamp(instance.timestamp),
  'success': ?instance.success,
  'data': ?instance.data,
};
