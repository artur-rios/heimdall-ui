// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'issue_application_token_command.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

IssueApplicationTokenCommand _$IssueApplicationTokenCommandFromJson(
  Map<String, dynamic> json,
) => IssueApplicationTokenCommand(
  applicationId: json['applicationId'] as String?,
  scopeId: json['scopeId'] as String?,
  secret: json['secret'] as String?,
);

Map<String, dynamic> _$IssueApplicationTokenCommandToJson(
  IssueApplicationTokenCommand instance,
) => <String, dynamic>{
  'applicationId': instance.applicationId,
  'scopeId': instance.scopeId,
  'secret': instance.secret,
};
