// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'issue_application_token_command_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

IssueApplicationTokenCommandOutput _$IssueApplicationTokenCommandOutputFromJson(
  Map<String, dynamic> json,
) {
  $checkKeys(
    json,
    allowedKeys: const ['id', 'token', 'expiresAt'],
    disallowNullValues: const ['id', 'expiresAt'],
  );
  return IssueApplicationTokenCommandOutput(
    id: json['id'] as String?,
    token: json['token'] as String?,
    expiresAt: IssueApplicationTokenCommandOutput._read_expiresAt(
      json['expiresAt'],
    ),
  );
}

Map<String, dynamic> _$IssueApplicationTokenCommandOutputToJson(
  IssueApplicationTokenCommandOutput instance,
) => <String, dynamic>{
  'id': ?instance.id,
  'token': ?instance.token,
  'expiresAt': ?IssueApplicationTokenCommandOutput._write_expiresAt(
    instance.expiresAt,
  ),
};
