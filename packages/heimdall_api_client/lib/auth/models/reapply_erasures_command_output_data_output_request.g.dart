// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reapply_erasures_command_output_data_output_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ReapplyErasuresCommandOutputDataOutput$Request
_$ReapplyErasuresCommandOutputDataOutput$RequestFromJson(
  Map<String, dynamic> json,
) {
  $checkKeys(
    json,
    allowedKeys: const ['messages', 'errors', 'timestamp', 'data'],
    disallowNullValues: const ['timestamp'],
  );
  return ReapplyErasuresCommandOutputDataOutput$Request(
    messages: (json['messages'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList(),
    errors: (json['errors'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList(),
    timestamp: ReapplyErasuresCommandOutputDataOutput$Request._read_timestamp(
      json['timestamp'],
    ),
    data: json['data'] == null
        ? null
        : ReapplyErasuresCommandOutput.fromJson(
            json['data'] as Map<String, dynamic>,
          ),
  );
}

Map<String, dynamic> _$ReapplyErasuresCommandOutputDataOutput$RequestToJson(
  ReapplyErasuresCommandOutputDataOutput$Request instance,
) => <String, dynamic>{
  'messages': ?instance.messages,
  'errors': ?instance.errors,
  'timestamp': ?ReapplyErasuresCommandOutputDataOutput$Request._write_timestamp(
    instance.timestamp,
  ),
  'data': ?instance.data?.toJson(),
};
