// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'google_sign_in_command_output.g.dart';

@JsonSerializable()
class GoogleSignInCommandOutput {
  const GoogleSignInCommandOutput({
    this.token,
    this.expiresAt,
    this.emailVerified,
    this.processingRestricted,
  });

  factory GoogleSignInCommandOutput.fromJson(Map<String, Object?> json) =>
      _$GoogleSignInCommandOutputFromJson(json);

  final String? token;
  final DateTime? expiresAt;
  final bool? emailVerified;
  final bool? processingRestricted;

  Map<String, Object?> toJson() => _$GoogleSignInCommandOutputToJson(this);
}
