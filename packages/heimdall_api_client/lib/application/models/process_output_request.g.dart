// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'process_output_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ProcessOutput$Request _$ProcessOutput$RequestFromJson(
  Map<String, dynamic> json,
) {
  $checkKeys(
    json,
    allowedKeys: const ['messages', 'errors', 'timestamp'],
    disallowNullValues: const ['timestamp'],
  );
  return ProcessOutput$Request(
    messages: (json['messages'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList(),
    errors: (json['errors'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList(),
    timestamp: ProcessOutput$Request._read_timestamp(json['timestamp']),
  );
}

Map<String, dynamic> _$ProcessOutput$RequestToJson(
  ProcessOutput$Request instance,
) => <String, dynamic>{
  'messages': ?instance.messages,
  'errors': ?instance.errors,
  'timestamp': ?ProcessOutput$Request._write_timestamp(instance.timestamp),
};
