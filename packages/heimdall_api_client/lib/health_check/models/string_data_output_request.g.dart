// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'string_data_output_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

StringDataOutput$Request _$StringDataOutput$RequestFromJson(
  Map<String, dynamic> json,
) {
  $checkKeys(
    json,
    allowedKeys: const ['messages', 'errors', 'timestamp', 'data'],
    disallowNullValues: const ['timestamp'],
  );
  return StringDataOutput$Request(
    messages: (json['messages'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList(),
    errors: (json['errors'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList(),
    timestamp: StringDataOutput$Request._read_timestamp(json['timestamp']),
    data: json['data'] as String?,
  );
}

Map<String, dynamic> _$StringDataOutput$RequestToJson(
  StringDataOutput$Request instance,
) => <String, dynamic>{
  'messages': ?instance.messages,
  'errors': ?instance.errors,
  'timestamp': ?StringDataOutput$Request._write_timestamp(instance.timestamp),
  'data': ?instance.data,
};
