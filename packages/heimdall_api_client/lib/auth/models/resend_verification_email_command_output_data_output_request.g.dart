// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'resend_verification_email_command_output_data_output_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ResendVerificationEmailCommandOutputDataOutput$Request
_$ResendVerificationEmailCommandOutputDataOutput$RequestFromJson(
  Map<String, dynamic> json,
) {
  $checkKeys(
    json,
    allowedKeys: const ['messages', 'errors', 'timestamp', 'data'],
    disallowNullValues: const ['timestamp'],
  );
  return ResendVerificationEmailCommandOutputDataOutput$Request(
    messages: (json['messages'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList(),
    errors: (json['errors'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList(),
    timestamp:
        ResendVerificationEmailCommandOutputDataOutput$Request._read_timestamp(
          json['timestamp'],
        ),
    data: json['data'] == null
        ? null
        : ResendVerificationEmailCommandOutput.fromJson(
            json['data'] as Map<String, dynamic>,
          ),
  );
}

Map<String, dynamic>
_$ResendVerificationEmailCommandOutputDataOutput$RequestToJson(
  ResendVerificationEmailCommandOutputDataOutput$Request instance,
) => <String, dynamic>{
  'messages': ?instance.messages,
  'errors': ?instance.errors,
  'timestamp':
      ?ResendVerificationEmailCommandOutputDataOutput$Request._write_timestamp(
        instance.timestamp,
      ),
  'data': ?instance.data?.toJson(),
};
