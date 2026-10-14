// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'application_token_check_output.g.dart';

@JsonSerializable()
class ApplicationTokenCheckOutput {
  const ApplicationTokenCheckOutput({
    this.applicationId,
    this.name,
    this.scopeId,
    this.credentialId,
    this.expiresAt,
  });

  factory ApplicationTokenCheckOutput.fromJson(Map<String, Object?> json) =>
      _$ApplicationTokenCheckOutputFromJson(json);

  final String? applicationId;
  final String? name;
  final String? scopeId;
  final String? credentialId;
  final DateTime? expiresAt;

  Map<String, Object?> toJson() => _$ApplicationTokenCheckOutputToJson(this);
}
