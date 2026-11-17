// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'string_data_output_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

StringDataOutput$Response _$StringDataOutput$ResponseFromJson(
  Map<String, dynamic> json,
) {
  $checkKeys(
    json,
    allowedKeys: const ['messages', 'errors', 'timestamp', 'success', 'data'],
    disallowNullValues: const ['timestamp', 'success'],
  );
  return StringDataOutput$Response(
    messages: (json['messages'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList(),
    errors: (json['errors'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList(),
    timestamp: StringDataOutput$Response._read_timestamp(json['timestamp']),
    success: json['success'] as bool?,
    data: json['data'] as String?,
  );
}

Map<String, dynamic> _$StringDataOutput$ResponseToJson(
  StringDataOutput$Response instance,
) => <String, dynamic>{
  'messages': ?instance.messages,
  'errors': ?instance.errors,
  'timestamp': ?StringDataOutput$Response._write_timestamp(instance.timestamp),
  'success': ?instance.success,
  'data': ?instance.data,
};
