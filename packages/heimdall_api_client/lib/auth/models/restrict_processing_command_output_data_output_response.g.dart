// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'restrict_processing_command_output_data_output_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RestrictProcessingCommandOutputDataOutput$Response
_$RestrictProcessingCommandOutputDataOutput$ResponseFromJson(
  Map<String, dynamic> json,
) {
  $checkKeys(
    json,
    allowedKeys: const ['messages', 'errors', 'timestamp', 'success', 'data'],
    disallowNullValues: const ['timestamp', 'success'],
  );
  return RestrictProcessingCommandOutputDataOutput$Response(
    messages: (json['messages'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList(),
    errors: (json['errors'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList(),
    timestamp:
        RestrictProcessingCommandOutputDataOutput$Response._read_timestamp(
          json['timestamp'],
        ),
    success: json['success'] as bool?,
    data: json['data'] == null
        ? null
        : RestrictProcessingCommandOutput.fromJson(
            json['data'] as Map<String, dynamic>,
          ),
  );
}

Map<String, dynamic> _$RestrictProcessingCommandOutputDataOutput$ResponseToJson(
  RestrictProcessingCommandOutputDataOutput$Response instance,
) => <String, dynamic>{
  'messages': ?instance.messages,
  'errors': ?instance.errors,
  'timestamp':
      ?RestrictProcessingCommandOutputDataOutput$Response._write_timestamp(
        instance.timestamp,
      ),
  'success': ?instance.success,
  'data': ?instance.data?.toJson(),
};
