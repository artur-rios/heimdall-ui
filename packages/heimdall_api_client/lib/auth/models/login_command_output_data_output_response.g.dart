// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'login_command_output_data_output_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LoginCommandOutputDataOutput$Response
_$LoginCommandOutputDataOutput$ResponseFromJson(Map<String, dynamic> json) {
  $checkKeys(
    json,
    allowedKeys: const ['messages', 'errors', 'timestamp', 'success', 'data'],
    disallowNullValues: const ['timestamp', 'success'],
  );
  return LoginCommandOutputDataOutput$Response(
    messages: (json['messages'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList(),
    errors: (json['errors'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList(),
    timestamp: LoginCommandOutputDataOutput$Response._read_timestamp(
      json['timestamp'],
    ),
    success: json['success'] as bool?,
    data: json['data'] == null
        ? null
        : LoginCommandOutput.fromJson(json['data'] as Map<String, dynamic>),
  );
}

Map<String, dynamic> _$LoginCommandOutputDataOutput$ResponseToJson(
  LoginCommandOutputDataOutput$Response instance,
) => <String, dynamic>{
  'messages': ?instance.messages,
  'errors': ?instance.errors,
  'timestamp': ?LoginCommandOutputDataOutput$Response._write_timestamp(
    instance.timestamp,
  ),
  'success': ?instance.success,
  'data': ?instance.data?.toJson(),
};
