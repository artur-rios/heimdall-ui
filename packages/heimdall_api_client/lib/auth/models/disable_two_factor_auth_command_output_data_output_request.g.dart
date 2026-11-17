// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'disable_two_factor_auth_command_output_data_output_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DisableTwoFactorAuthCommandOutputDataOutput$Request
_$DisableTwoFactorAuthCommandOutputDataOutput$RequestFromJson(
  Map<String, dynamic> json,
) {
  $checkKeys(
    json,
    allowedKeys: const ['messages', 'errors', 'timestamp', 'data'],
    disallowNullValues: const ['timestamp'],
  );
  return DisableTwoFactorAuthCommandOutputDataOutput$Request(
    messages: (json['messages'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList(),
    errors: (json['errors'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList(),
    timestamp:
        DisableTwoFactorAuthCommandOutputDataOutput$Request._read_timestamp(
          json['timestamp'],
        ),
    data: json['data'] == null
        ? null
        : DisableTwoFactorAuthCommandOutput.fromJson(
            json['data'] as Map<String, dynamic>,
          ),
  );
}

Map<String, dynamic>
_$DisableTwoFactorAuthCommandOutputDataOutput$RequestToJson(
  DisableTwoFactorAuthCommandOutputDataOutput$Request instance,
) => <String, dynamic>{
  'messages': ?instance.messages,
  'errors': ?instance.errors,
  'timestamp':
      ?DisableTwoFactorAuthCommandOutputDataOutput$Request._write_timestamp(
        instance.timestamp,
      ),
  'data': ?instance.data?.toJson(),
};
