// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'application_credential_output.g.dart';

@JsonSerializable()
class ApplicationCredentialOutput {
  const ApplicationCredentialOutput({
    this.id,
    this.createdAt,
    this.expiresAt,
    this.revokedAt,
    this.lastUsedAt,
    this.live,
  });

  factory ApplicationCredentialOutput.fromJson(Map<String, Object?> json) =>
      _$ApplicationCredentialOutputFromJson(json);

  final String? id;
  final DateTime? createdAt;
  final DateTime? expiresAt;
  final DateTime? revokedAt;
  final DateTime? lastUsedAt;
  final bool? live;

  Map<String, Object?> toJson() => _$ApplicationCredentialOutputToJson(this);
}
