// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'delete_google_user_command_output_data_output_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DeleteGoogleUserCommandOutputDataOutput$Request
_$DeleteGoogleUserCommandOutputDataOutput$RequestFromJson(
  Map<String, dynamic> json,
) {
  $checkKeys(
    json,
    allowedKeys: const ['messages', 'errors', 'timestamp', 'data'],
    disallowNullValues: const ['timestamp'],
  );
  return DeleteGoogleUserCommandOutputDataOutput$Request(
    messages: (json['messages'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList(),
    errors: (json['errors'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList(),
    timestamp: DeleteGoogleUserCommandOutputDataOutput$Request._read_timestamp(
      json['timestamp'],
    ),
    data: json['data'] == null
        ? null
        : DeleteGoogleUserCommandOutput.fromJson(
            json['data'] as Map<String, dynamic>,
          ),
  );
}

Map<String, dynamic> _$DeleteGoogleUserCommandOutputDataOutput$RequestToJson(
  DeleteGoogleUserCommandOutputDataOutput$Request instance,
) => <String, dynamic>{
  'messages': ?instance.messages,
  'errors': ?instance.errors,
  'timestamp':
      ?DeleteGoogleUserCommandOutputDataOutput$Request._write_timestamp(
        instance.timestamp,
      ),
  'data': ?instance.data?.toJson(),
};
