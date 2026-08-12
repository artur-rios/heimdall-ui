// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'verify_two_factor_auth_command_output_data_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

VerifyTwoFactorAuthCommandOutputDataOutput
_$VerifyTwoFactorAuthCommandOutputDataOutputFromJson(
  Map<String, dynamic> json,
) => VerifyTwoFactorAuthCommandOutputDataOutput(
  messages: (json['messages'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  errors: (json['errors'] as List<dynamic>?)?.map((e) => e as String).toList(),
  timestamp: json['timestamp'] == null
      ? null
      : DateTime.parse(json['timestamp'] as String),
  success: json['success'] as bool?,
  data: json['data'] == null
      ? null
      : VerifyTwoFactorAuthCommandOutput.fromJson(
          json['data'] as Map<String, dynamic>,
        ),
);

Map<String, dynamic> _$VerifyTwoFactorAuthCommandOutputDataOutputToJson(
  VerifyTwoFactorAuthCommandOutputDataOutput instance,
) => <String, dynamic>{
  'messages': instance.messages,
  'errors': instance.errors,
  'timestamp': instance.timestamp?.toIso8601String(),
  'success': instance.success,
  'data': instance.data,
};
