// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'revoke_application_credential_command_output_data_output_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RevokeApplicationCredentialCommandOutputDataOutput$Request
_$RevokeApplicationCredentialCommandOutputDataOutput$RequestFromJson(
  Map<String, dynamic> json,
) {
  $checkKeys(
    json,
    allowedKeys: const ['messages', 'errors', 'timestamp', 'data'],
    disallowNullValues: const ['timestamp'],
  );
  return RevokeApplicationCredentialCommandOutputDataOutput$Request(
    messages: (json['messages'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList(),
    errors: (json['errors'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList(),
    timestamp:
        RevokeApplicationCredentialCommandOutputDataOutput$Request._read_timestamp(
          json['timestamp'],
        ),
    data: json['data'] == null
        ? null
        : RevokeApplicationCredentialCommandOutput.fromJson(
            json['data'] as Map<String, dynamic>,
          ),
  );
}

Map<String, dynamic>
_$RevokeApplicationCredentialCommandOutputDataOutput$RequestToJson(
  RevokeApplicationCredentialCommandOutputDataOutput$Request instance,
) => <String, dynamic>{
  'messages': ?instance.messages,
  'errors': ?instance.errors,
  'timestamp':
      ?RevokeApplicationCredentialCommandOutputDataOutput$Request._write_timestamp(
        instance.timestamp,
      ),
  'data': ?instance.data?.toJson(),
};
