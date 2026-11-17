// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'add_scope_owner_command_output_data_output_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AddScopeOwnerCommandOutputDataOutput$Request
_$AddScopeOwnerCommandOutputDataOutput$RequestFromJson(
  Map<String, dynamic> json,
) {
  $checkKeys(
    json,
    allowedKeys: const ['messages', 'errors', 'timestamp', 'data'],
    disallowNullValues: const ['timestamp'],
  );
  return AddScopeOwnerCommandOutputDataOutput$Request(
    messages: (json['messages'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList(),
    errors: (json['errors'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList(),
    timestamp: AddScopeOwnerCommandOutputDataOutput$Request._read_timestamp(
      json['timestamp'],
    ),
    data: json['data'] == null
        ? null
        : AddScopeOwnerCommandOutput.fromJson(
            json['data'] as Map<String, dynamic>,
          ),
  );
}

Map<String, dynamic> _$AddScopeOwnerCommandOutputDataOutput$RequestToJson(
  AddScopeOwnerCommandOutputDataOutput$Request instance,
) => <String, dynamic>{
  'messages': ?instance.messages,
  'errors': ?instance.errors,
  'timestamp': ?AddScopeOwnerCommandOutputDataOutput$Request._write_timestamp(
    instance.timestamp,
  ),
  'data': ?instance.data?.toJson(),
};
