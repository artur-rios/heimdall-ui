// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'issue_application_credential_command.g.dart';

@JsonSerializable()
class IssueApplicationCredentialCommand {
  const IssueApplicationCredentialCommand({this.expiresAt});

  factory IssueApplicationCredentialCommand.fromJson(
    Map<String, Object?> json,
  ) => _$IssueApplicationCredentialCommandFromJson(json);

  final DateTime? expiresAt;

  Map<String, Object?> toJson() =>
      _$IssueApplicationCredentialCommandToJson(this);
}
