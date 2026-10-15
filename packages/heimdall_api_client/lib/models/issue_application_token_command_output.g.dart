// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'issue_application_token_command_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

IssueApplicationTokenCommandOutput _$IssueApplicationTokenCommandOutputFromJson(
  Map<String, dynamic> json,
) => IssueApplicationTokenCommandOutput(
  id: json['id'] as String?,
  token: json['token'] as String?,
  expiresAt: json['expiresAt'] == null
      ? null
      : DateTime.parse(json['expiresAt'] as String),
);

Map<String, dynamic> _$IssueApplicationTokenCommandOutputToJson(
  IssueApplicationTokenCommandOutput instance,
) => <String, dynamic>{
  'id': instance.id,
  'token': instance.token,
  'expiresAt': instance.expiresAt?.toIso8601String(),
};
