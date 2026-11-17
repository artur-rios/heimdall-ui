// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'issue_application_token_command_output_data_output_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

IssueApplicationTokenCommandOutputDataOutput$Response
_$IssueApplicationTokenCommandOutputDataOutput$ResponseFromJson(
  Map<String, dynamic> json,
) {
  $checkKeys(
    json,
    allowedKeys: const ['messages', 'errors', 'timestamp', 'success', 'data'],
    disallowNullValues: const ['timestamp', 'success'],
  );
  return IssueApplicationTokenCommandOutputDataOutput$Response(
    messages: (json['messages'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList(),
    errors: (json['errors'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList(),
    timestamp:
        IssueApplicationTokenCommandOutputDataOutput$Response._read_timestamp(
          json['timestamp'],
        ),
    success: json['success'] as bool?,
    data: json['data'] == null
        ? null
        : IssueApplicationTokenCommandOutput.fromJson(
            json['data'] as Map<String, dynamic>,
          ),
  );
}

Map<String, dynamic>
_$IssueApplicationTokenCommandOutputDataOutput$ResponseToJson(
  IssueApplicationTokenCommandOutputDataOutput$Response instance,
) => <String, dynamic>{
  'messages': ?instance.messages,
  'errors': ?instance.errors,
  'timestamp':
      ?IssueApplicationTokenCommandOutputDataOutput$Response._write_timestamp(
        instance.timestamp,
      ),
  'success': ?instance.success,
  'data': ?instance.data?.toJson(),
};
