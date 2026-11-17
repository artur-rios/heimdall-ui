// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_application_command_output_data_output_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreateApplicationCommandOutputDataOutput$Response
_$CreateApplicationCommandOutputDataOutput$ResponseFromJson(
  Map<String, dynamic> json,
) {
  $checkKeys(
    json,
    allowedKeys: const ['messages', 'errors', 'timestamp', 'success', 'data'],
    disallowNullValues: const ['timestamp', 'success'],
  );
  return CreateApplicationCommandOutputDataOutput$Response(
    messages: (json['messages'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList(),
    errors: (json['errors'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList(),
    timestamp:
        CreateApplicationCommandOutputDataOutput$Response._read_timestamp(
          json['timestamp'],
        ),
    success: json['success'] as bool?,
    data: json['data'] == null
        ? null
        : CreateApplicationCommandOutput.fromJson(
            json['data'] as Map<String, dynamic>,
          ),
  );
}

Map<String, dynamic> _$CreateApplicationCommandOutputDataOutput$ResponseToJson(
  CreateApplicationCommandOutputDataOutput$Response instance,
) => <String, dynamic>{
  'messages': ?instance.messages,
  'errors': ?instance.errors,
  'timestamp':
      ?CreateApplicationCommandOutputDataOutput$Response._write_timestamp(
        instance.timestamp,
      ),
  'success': ?instance.success,
  'data': ?instance.data?.toJson(),
};
