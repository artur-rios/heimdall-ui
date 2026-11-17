// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'process_output_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ProcessOutput$Response _$ProcessOutput$ResponseFromJson(
  Map<String, dynamic> json,
) {
  $checkKeys(
    json,
    allowedKeys: const ['messages', 'errors', 'timestamp', 'success'],
    disallowNullValues: const ['timestamp', 'success'],
  );
  return ProcessOutput$Response(
    messages: (json['messages'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList(),
    errors: (json['errors'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList(),
    timestamp: ProcessOutput$Response._read_timestamp(json['timestamp']),
    success: json['success'] as bool?,
  );
}

Map<String, dynamic> _$ProcessOutput$ResponseToJson(
  ProcessOutput$Response instance,
) => <String, dynamic>{
  'messages': ?instance.messages,
  'errors': ?instance.errors,
  'timestamp': ?ProcessOutput$Response._write_timestamp(instance.timestamp),
  'success': ?instance.success,
};
