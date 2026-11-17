// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'object_data_output_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ObjectDataOutput$Request _$ObjectDataOutput$RequestFromJson(
  Map<String, dynamic> json,
) {
  $checkKeys(
    json,
    allowedKeys: const ['messages', 'errors', 'timestamp', 'data'],
    disallowNullValues: const ['timestamp'],
  );
  return ObjectDataOutput$Request(
    messages: (json['messages'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList(),
    errors: (json['errors'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList(),
    timestamp: ObjectDataOutput$Request._read_timestamp(json['timestamp']),
    data: json['data'],
  );
}

Map<String, dynamic> _$ObjectDataOutput$RequestToJson(
  ObjectDataOutput$Request instance,
) => <String, dynamic>{
  'messages': ?instance.messages,
  'errors': ?instance.errors,
  'timestamp': ?ObjectDataOutput$Request._write_timestamp(instance.timestamp),
  'data': ?instance.data,
};
