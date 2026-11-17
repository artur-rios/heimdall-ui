// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'issue_application_credential_command.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

IssueApplicationCredentialCommand _$IssueApplicationCredentialCommandFromJson(
  Map<String, dynamic> json,
) {
  $checkKeys(json, allowedKeys: const ['expiresAt']);
  return IssueApplicationCredentialCommand(
    expiresAt: IssueApplicationCredentialCommand._read_expiresAt(
      json['expiresAt'],
    ),
  );
}

Map<String, dynamic> _$IssueApplicationCredentialCommandToJson(
  IssueApplicationCredentialCommand instance,
) => <String, dynamic>{
  'expiresAt': ?IssueApplicationCredentialCommand._write_expiresAt(
    instance.expiresAt,
  ),
};
