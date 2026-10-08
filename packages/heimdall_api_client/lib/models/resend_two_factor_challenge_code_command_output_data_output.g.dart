// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'resend_two_factor_challenge_code_command_output_data_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ResendTwoFactorChallengeCodeCommandOutputDataOutput
_$ResendTwoFactorChallengeCodeCommandOutputDataOutputFromJson(
  Map<String, dynamic> json,
) => ResendTwoFactorChallengeCodeCommandOutputDataOutput(
  messages: (json['messages'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  errors: (json['errors'] as List<dynamic>?)?.map((e) => e as String).toList(),
  timestamp: json['timestamp'] == null
      ? null
      : DateTime.parse(json['timestamp'] as String),
  success: json['success'] as bool?,
  data: json['data'],
);

Map<String, dynamic>
_$ResendTwoFactorChallengeCodeCommandOutputDataOutputToJson(
  ResendTwoFactorChallengeCodeCommandOutputDataOutput instance,
) => <String, dynamic>{
  'messages': instance.messages,
  'errors': instance.errors,
  'timestamp': instance.timestamp?.toIso8601String(),
  'success': instance.success,
  'data': instance.data,
};
