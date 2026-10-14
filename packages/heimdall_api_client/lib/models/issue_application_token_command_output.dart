// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'issue_application_token_command_output.g.dart';

@JsonSerializable()
class IssueApplicationTokenCommandOutput {
  const IssueApplicationTokenCommandOutput({
    this.id,
    this.token,
    this.expiresAt,
  });

  factory IssueApplicationTokenCommandOutput.fromJson(
    Map<String, Object?> json,
  ) => _$IssueApplicationTokenCommandOutputFromJson(json);

  final String? id;
  final String? token;
  final DateTime? expiresAt;

  Map<String, Object?> toJson() =>
      _$IssueApplicationTokenCommandOutputToJson(this);
}
