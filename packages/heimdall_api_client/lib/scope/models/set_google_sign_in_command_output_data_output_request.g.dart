// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'set_google_sign_in_command_output_data_output_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SetGoogleSignInCommandOutputDataOutput$Request
_$SetGoogleSignInCommandOutputDataOutput$RequestFromJson(
  Map<String, dynamic> json,
) {
  $checkKeys(
    json,
    allowedKeys: const ['messages', 'errors', 'timestamp', 'data'],
    disallowNullValues: const ['timestamp'],
  );
  return SetGoogleSignInCommandOutputDataOutput$Request(
    messages: (json['messages'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList(),
    errors: (json['errors'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList(),
    timestamp: SetGoogleSignInCommandOutputDataOutput$Request._read_timestamp(
      json['timestamp'],
    ),
    data: json['data'] == null
        ? null
        : SetGoogleSignInCommandOutput.fromJson(
            json['data'] as Map<String, dynamic>,
          ),
  );
}

Map<String, dynamic> _$SetGoogleSignInCommandOutputDataOutput$RequestToJson(
  SetGoogleSignInCommandOutputDataOutput$Request instance,
) => <String, dynamic>{
  'messages': ?instance.messages,
  'errors': ?instance.errors,
  'timestamp': ?SetGoogleSignInCommandOutputDataOutput$Request._write_timestamp(
    instance.timestamp,
  ),
  'data': ?instance.data?.toJson(),
};
