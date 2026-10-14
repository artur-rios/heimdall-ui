// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'issue_application_credential_command_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

IssueApplicationCredentialCommandOutput
_$IssueApplicationCredentialCommandOutputFromJson(Map<String, dynamic> json) =>
    IssueApplicationCredentialCommandOutput(
      id: json['id'] as String?,
      secret: json['secret'] as String?,
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
      expiresAt: json['expiresAt'] == null
          ? null
          : DateTime.parse(json['expiresAt'] as String),
    );

Map<String, dynamic> _$IssueApplicationCredentialCommandOutputToJson(
  IssueApplicationCredentialCommandOutput instance,
) => <String, dynamic>{
  'id': instance.id,
  'secret': instance.secret,
  'createdAt': instance.createdAt?.toIso8601String(),
  'expiresAt': instance.expiresAt?.toIso8601String(),
};
