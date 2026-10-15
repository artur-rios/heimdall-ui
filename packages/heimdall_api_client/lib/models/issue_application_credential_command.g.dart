// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'issue_application_credential_command.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

IssueApplicationCredentialCommand _$IssueApplicationCredentialCommandFromJson(
  Map<String, dynamic> json,
) => IssueApplicationCredentialCommand(
  expiresAt: json['expiresAt'] == null
      ? null
      : DateTime.parse(json['expiresAt'] as String),
);

Map<String, dynamic> _$IssueApplicationCredentialCommandToJson(
  IssueApplicationCredentialCommand instance,
) => <String, dynamic>{'expiresAt': instance.expiresAt?.toIso8601String()};
