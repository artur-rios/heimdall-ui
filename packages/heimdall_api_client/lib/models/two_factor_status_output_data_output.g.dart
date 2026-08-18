// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'two_factor_status_output_data_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TwoFactorStatusOutputDataOutput _$TwoFactorStatusOutputDataOutputFromJson(
  Map<String, dynamic> json,
) => TwoFactorStatusOutputDataOutput(
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
      : TwoFactorStatusOutput.fromJson(json['data'] as Map<String, dynamic>),
);

Map<String, dynamic> _$TwoFactorStatusOutputDataOutputToJson(
  TwoFactorStatusOutputDataOutput instance,
) => <String, dynamic>{
  'messages': instance.messages,
  'errors': instance.errors,
  'timestamp': instance.timestamp?.toIso8601String(),
  'success': instance.success,
  'data': instance.data,
};
