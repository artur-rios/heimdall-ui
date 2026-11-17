// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'person_output_data_output_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PersonOutputDataOutput$Response _$PersonOutputDataOutput$ResponseFromJson(
  Map<String, dynamic> json,
) {
  $checkKeys(
    json,
    allowedKeys: const ['messages', 'errors', 'timestamp', 'success', 'data'],
    disallowNullValues: const ['timestamp', 'success'],
  );
  return PersonOutputDataOutput$Response(
    messages: (json['messages'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList(),
    errors: (json['errors'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList(),
    timestamp: PersonOutputDataOutput$Response._read_timestamp(
      json['timestamp'],
    ),
    success: json['success'] as bool?,
    data: json['data'] == null
        ? null
        : PersonOutput.fromJson(json['data'] as Map<String, dynamic>),
  );
}

Map<String, dynamic> _$PersonOutputDataOutput$ResponseToJson(
  PersonOutputDataOutput$Response instance,
) => <String, dynamic>{
  'messages': ?instance.messages,
  'errors': ?instance.errors,
  'timestamp': ?PersonOutputDataOutput$Response._write_timestamp(
    instance.timestamp,
  ),
  'success': ?instance.success,
  'data': ?instance.data?.toJson(),
};
