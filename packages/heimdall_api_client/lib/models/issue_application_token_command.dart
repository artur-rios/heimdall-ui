// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'issue_application_token_command.g.dart';

@JsonSerializable()
class IssueApplicationTokenCommand {
  const IssueApplicationTokenCommand({
    this.applicationId,
    this.scopeId,
    this.secret,
  });

  factory IssueApplicationTokenCommand.fromJson(Map<String, Object?> json) =>
      _$IssueApplicationTokenCommandFromJson(json);

  final String? applicationId;
  final String? scopeId;
  final String? secret;

  Map<String, Object?> toJson() => _$IssueApplicationTokenCommandToJson(this);
}
