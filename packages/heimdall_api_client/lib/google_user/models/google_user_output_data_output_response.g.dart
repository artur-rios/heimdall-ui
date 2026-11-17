// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'google_user_output_data_output_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GoogleUserOutputDataOutput$Response
_$GoogleUserOutputDataOutput$ResponseFromJson(Map<String, dynamic> json) {
  $checkKeys(
    json,
    allowedKeys: const ['messages', 'errors', 'timestamp', 'success', 'data'],
    disallowNullValues: const ['timestamp', 'success'],
  );
  return GoogleUserOutputDataOutput$Response(
    messages: (json['messages'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList(),
    errors: (json['errors'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList(),
    timestamp: GoogleUserOutputDataOutput$Response._read_timestamp(
      json['timestamp'],
    ),
    success: json['success'] as bool?,
    data: json['data'] == null
        ? null
        : GoogleUserOutput.fromJson(json['data'] as Map<String, dynamic>),
  );
}

Map<String, dynamic> _$GoogleUserOutputDataOutput$ResponseToJson(
  GoogleUserOutputDataOutput$Response instance,
) => <String, dynamic>{
  'messages': ?instance.messages,
  'errors': ?instance.errors,
  'timestamp': ?GoogleUserOutputDataOutput$Response._write_timestamp(
    instance.timestamp,
  ),
  'success': ?instance.success,
  'data': ?instance.data?.toJson(),
};
