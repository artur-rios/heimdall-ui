// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'issue_application_credential_command_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

IssueApplicationCredentialCommandOutput
_$IssueApplicationCredentialCommandOutputFromJson(Map<String, dynamic> json) {
  $checkKeys(
    json,
    allowedKeys: const ['id', 'secret', 'createdAt', 'expiresAt'],
    disallowNullValues: const ['id', 'createdAt'],
  );
  return IssueApplicationCredentialCommandOutput(
    id: json['id'] as String?,
    secret: json['secret'] as String?,
    createdAt: IssueApplicationCredentialCommandOutput._read_createdAt(
      json['createdAt'],
    ),
    expiresAt: IssueApplicationCredentialCommandOutput._read_expiresAt(
      json['expiresAt'],
    ),
  );
}

Map<String, dynamic> _$IssueApplicationCredentialCommandOutputToJson(
  IssueApplicationCredentialCommandOutput instance,
) => <String, dynamic>{
  'id': ?instance.id,
  'secret': ?instance.secret,
  'createdAt': ?IssueApplicationCredentialCommandOutput._write_createdAt(
    instance.createdAt,
  ),
  'expiresAt': ?IssueApplicationCredentialCommandOutput._write_expiresAt(
    instance.expiresAt,
  ),
};
