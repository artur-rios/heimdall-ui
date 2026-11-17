// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'confirm_two_factor_auth_command_output_data_output_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ConfirmTwoFactorAuthCommandOutputDataOutput$Request
_$ConfirmTwoFactorAuthCommandOutputDataOutput$RequestFromJson(
  Map<String, dynamic> json,
) {
  $checkKeys(
    json,
    allowedKeys: const ['messages', 'errors', 'timestamp', 'data'],
    disallowNullValues: const ['timestamp'],
  );
  return ConfirmTwoFactorAuthCommandOutputDataOutput$Request(
    messages: (json['messages'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList(),
    errors: (json['errors'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList(),
    timestamp:
        ConfirmTwoFactorAuthCommandOutputDataOutput$Request._read_timestamp(
          json['timestamp'],
        ),
    data: json['data'] == null
        ? null
        : ConfirmTwoFactorAuthCommandOutput.fromJson(
            json['data'] as Map<String, dynamic>,
          ),
  );
}

Map<String, dynamic>
_$ConfirmTwoFactorAuthCommandOutputDataOutput$RequestToJson(
  ConfirmTwoFactorAuthCommandOutputDataOutput$Request instance,
) => <String, dynamic>{
  'messages': ?instance.messages,
  'errors': ?instance.errors,
  'timestamp':
      ?ConfirmTwoFactorAuthCommandOutputDataOutput$Request._write_timestamp(
        instance.timestamp,
      ),
  'data': ?instance.data?.toJson(),
};
