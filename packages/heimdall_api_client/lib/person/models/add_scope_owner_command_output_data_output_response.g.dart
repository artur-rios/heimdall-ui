// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'add_scope_owner_command_output_data_output_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AddScopeOwnerCommandOutputDataOutput$Response
_$AddScopeOwnerCommandOutputDataOutput$ResponseFromJson(
  Map<String, dynamic> json,
) {
  $checkKeys(
    json,
    allowedKeys: const ['messages', 'errors', 'timestamp', 'success', 'data'],
    disallowNullValues: const ['timestamp', 'success'],
  );
  return AddScopeOwnerCommandOutputDataOutput$Response(
    messages: (json['messages'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList(),
    errors: (json['errors'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList(),
    timestamp: AddScopeOwnerCommandOutputDataOutput$Response._read_timestamp(
      json['timestamp'],
    ),
    success: json['success'] as bool?,
    data: json['data'] == null
        ? null
        : AddScopeOwnerCommandOutput.fromJson(
            json['data'] as Map<String, dynamic>,
          ),
  );
}

Map<String, dynamic> _$AddScopeOwnerCommandOutputDataOutput$ResponseToJson(
  AddScopeOwnerCommandOutputDataOutput$Response instance,
) => <String, dynamic>{
  'messages': ?instance.messages,
  'errors': ?instance.errors,
  'timestamp': ?AddScopeOwnerCommandOutputDataOutput$Response._write_timestamp(
    instance.timestamp,
  ),
  'success': ?instance.success,
  'data': ?instance.data?.toJson(),
};
