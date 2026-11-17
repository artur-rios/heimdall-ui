// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'person_output_data_output_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PersonOutputDataOutput$Request _$PersonOutputDataOutput$RequestFromJson(
  Map<String, dynamic> json,
) {
  $checkKeys(
    json,
    allowedKeys: const ['messages', 'errors', 'timestamp', 'data'],
    disallowNullValues: const ['timestamp', 'data'],
  );
  return PersonOutputDataOutput$Request(
    messages: (json['messages'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList(),
    errors: (json['errors'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList(),
    timestamp: PersonOutputDataOutput$Request._read_timestamp(
      json['timestamp'],
    ),
    data: json['data'] == null
        ? null
        : PersonOutput.fromJson(json['data'] as Map<String, dynamic>),
  );
}

Map<String, dynamic> _$PersonOutputDataOutput$RequestToJson(
  PersonOutputDataOutput$Request instance,
) => <String, dynamic>{
  'messages': ?instance.messages,
  'errors': ?instance.errors,
  'timestamp': ?PersonOutputDataOutput$Request._write_timestamp(
    instance.timestamp,
  ),
  'data': ?instance.data?.toJson(),
};
