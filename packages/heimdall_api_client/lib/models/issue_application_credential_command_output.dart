// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'issue_application_credential_command_output.g.dart';

@JsonSerializable()
class IssueApplicationCredentialCommandOutput {
  const IssueApplicationCredentialCommandOutput({
    this.id,
    this.secret,
    this.createdAt,
    this.expiresAt,
  });

  factory IssueApplicationCredentialCommandOutput.fromJson(
    Map<String, Object?> json,
  ) => _$IssueApplicationCredentialCommandOutputFromJson(json);

  final String? id;
  final String? secret;
  final DateTime? createdAt;
  final DateTime? expiresAt;

  Map<String, Object?> toJson() =>
      _$IssueApplicationCredentialCommandOutputToJson(this);
}
