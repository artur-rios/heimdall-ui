// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'resend_two_factor_challenge_code_command_output_data_output_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ResendTwoFactorChallengeCodeCommandOutputDataOutput$Request
_$ResendTwoFactorChallengeCodeCommandOutputDataOutput$RequestFromJson(
  Map<String, dynamic> json,
) {
  $checkKeys(
    json,
    allowedKeys: const ['messages', 'errors', 'timestamp', 'data'],
    disallowNullValues: const ['timestamp'],
  );
  return ResendTwoFactorChallengeCodeCommandOutputDataOutput$Request(
    messages: (json['messages'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList(),
    errors: (json['errors'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList(),
    timestamp:
        ResendTwoFactorChallengeCodeCommandOutputDataOutput$Request._read_timestamp(
          json['timestamp'],
        ),
    data: json['data'] == null
        ? null
        : ResendTwoFactorChallengeCodeCommandOutput.fromJson(
            json['data'] as Map<String, dynamic>,
          ),
  );
}

Map<String, dynamic>
_$ResendTwoFactorChallengeCodeCommandOutputDataOutput$RequestToJson(
  ResendTwoFactorChallengeCodeCommandOutputDataOutput$Request instance,
) => <String, dynamic>{
  'messages': ?instance.messages,
  'errors': ?instance.errors,
  'timestamp':
      ?ResendTwoFactorChallengeCodeCommandOutputDataOutput$Request._write_timestamp(
        instance.timestamp,
      ),
  'data': ?instance.data?.toJson(),
};
