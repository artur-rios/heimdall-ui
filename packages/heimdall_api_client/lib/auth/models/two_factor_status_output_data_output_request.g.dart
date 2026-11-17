// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'two_factor_status_output_data_output_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TwoFactorStatusOutputDataOutput$Request
_$TwoFactorStatusOutputDataOutput$RequestFromJson(Map<String, dynamic> json) {
  $checkKeys(
    json,
    allowedKeys: const ['messages', 'errors', 'timestamp', 'data'],
    disallowNullValues: const ['timestamp', 'data'],
  );
  return TwoFactorStatusOutputDataOutput$Request(
    messages: (json['messages'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList(),
    errors: (json['errors'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList(),
    timestamp: TwoFactorStatusOutputDataOutput$Request._read_timestamp(
      json['timestamp'],
    ),
    data: json['data'] == null
        ? null
        : TwoFactorStatusOutput.fromJson(json['data'] as Map<String, dynamic>),
  );
}

Map<String, dynamic> _$TwoFactorStatusOutputDataOutput$RequestToJson(
  TwoFactorStatusOutputDataOutput$Request instance,
) => <String, dynamic>{
  'messages': ?instance.messages,
  'errors': ?instance.errors,
  'timestamp': ?TwoFactorStatusOutputDataOutput$Request._write_timestamp(
    instance.timestamp,
  ),
  'data': ?instance.data?.toJson(),
};
