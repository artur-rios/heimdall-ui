// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'update_scope_command_output_data_output_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UpdateScopeCommandOutputDataOutput$Request
_$UpdateScopeCommandOutputDataOutput$RequestFromJson(
  Map<String, dynamic> json,
) {
  $checkKeys(
    json,
    allowedKeys: const ['messages', 'errors', 'timestamp', 'data'],
    disallowNullValues: const ['timestamp'],
  );
  return UpdateScopeCommandOutputDataOutput$Request(
    messages: (json['messages'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList(),
    errors: (json['errors'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList(),
    timestamp: UpdateScopeCommandOutputDataOutput$Request._read_timestamp(
      json['timestamp'],
    ),
    data: json['data'] == null
        ? null
        : UpdateScopeCommandOutput.fromJson(
            json['data'] as Map<String, dynamic>,
          ),
  );
}

Map<String, dynamic> _$UpdateScopeCommandOutputDataOutput$RequestToJson(
  UpdateScopeCommandOutputDataOutput$Request instance,
) => <String, dynamic>{
  'messages': ?instance.messages,
  'errors': ?instance.errors,
  'timestamp': ?UpdateScopeCommandOutputDataOutput$Request._write_timestamp(
    instance.timestamp,
  ),
  'data': ?instance.data?.toJson(),
};
