// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'delete_person_command_output_data_output_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DeletePersonCommandOutputDataOutput$Response
_$DeletePersonCommandOutputDataOutput$ResponseFromJson(
  Map<String, dynamic> json,
) {
  $checkKeys(
    json,
    allowedKeys: const ['messages', 'errors', 'timestamp', 'success', 'data'],
    disallowNullValues: const ['timestamp', 'success'],
  );
  return DeletePersonCommandOutputDataOutput$Response(
    messages: (json['messages'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList(),
    errors: (json['errors'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList(),
    timestamp: DeletePersonCommandOutputDataOutput$Response._read_timestamp(
      json['timestamp'],
    ),
    success: json['success'] as bool?,
    data: json['data'] == null
        ? null
        : DeletePersonCommandOutput.fromJson(
            json['data'] as Map<String, dynamic>,
          ),
  );
}

Map<String, dynamic> _$DeletePersonCommandOutputDataOutput$ResponseToJson(
  DeletePersonCommandOutputDataOutput$Response instance,
) => <String, dynamic>{
  'messages': ?instance.messages,
  'errors': ?instance.errors,
  'timestamp': ?DeletePersonCommandOutputDataOutput$Response._write_timestamp(
    instance.timestamp,
  ),
  'success': ?instance.success,
  'data': ?instance.data?.toJson(),
};
