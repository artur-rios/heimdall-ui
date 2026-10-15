// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'issue_application_credential_command_output.dart';

part 'issue_application_credential_command_output_data_output.g.dart';

@JsonSerializable()
class IssueApplicationCredentialCommandOutputDataOutput {
  const IssueApplicationCredentialCommandOutputDataOutput({
    this.messages,
    this.errors,
    this.timestamp,
    this.success,
    this.data,
  });

  factory IssueApplicationCredentialCommandOutputDataOutput.fromJson(
    Map<String, Object?> json,
  ) => _$IssueApplicationCredentialCommandOutputDataOutputFromJson(json);

  final List<String>? messages;
  final List<String>? errors;
  final DateTime? timestamp;
  final bool? success;
  final IssueApplicationCredentialCommandOutput? data;

  Map<String, Object?> toJson() =>
      _$IssueApplicationCredentialCommandOutputDataOutputToJson(this);
}
