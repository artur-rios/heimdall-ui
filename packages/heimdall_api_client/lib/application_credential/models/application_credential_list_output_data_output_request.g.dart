// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'application_credential_list_output_data_output_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ApplicationCredentialListOutputDataOutput$Request
_$ApplicationCredentialListOutputDataOutput$RequestFromJson(
  Map<String, dynamic> json,
) {
  $checkKeys(
    json,
    allowedKeys: const ['messages', 'errors', 'timestamp', 'data'],
    disallowNullValues: const ['timestamp'],
  );
  return ApplicationCredentialListOutputDataOutput$Request(
    messages: (json['messages'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList(),
    errors: (json['errors'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList(),
    timestamp:
        ApplicationCredentialListOutputDataOutput$Request._read_timestamp(
          json['timestamp'],
        ),
    data: json['data'] == null
        ? null
        : ApplicationCredentialListOutput.fromJson(
            json['data'] as Map<String, dynamic>,
          ),
  );
}

Map<String, dynamic> _$ApplicationCredentialListOutputDataOutput$RequestToJson(
  ApplicationCredentialListOutputDataOutput$Request instance,
) => <String, dynamic>{
  'messages': ?instance.messages,
  'errors': ?instance.errors,
  'timestamp':
      ?ApplicationCredentialListOutputDataOutput$Request._write_timestamp(
        instance.timestamp,
      ),
  'data': ?instance.data?.toJson(),
};
