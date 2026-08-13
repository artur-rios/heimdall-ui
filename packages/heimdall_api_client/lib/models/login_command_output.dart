// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'login_command_output.g.dart';

@JsonSerializable()
class LoginCommandOutput {
  const LoginCommandOutput({
    this.token,
    this.expiresAt,
    this.requiresTwoFactor,
    this.challengeToken,
    this.availableMethods,
  });

  factory LoginCommandOutput.fromJson(Map<String, Object?> json) =>
      _$LoginCommandOutputFromJson(json);

  final String? token;
  final DateTime? expiresAt;
  final bool? requiresTwoFactor;
  final String? challengeToken;
  final List<String>? availableMethods;

  Map<String, Object?> toJson() => _$LoginCommandOutputToJson(this);
}
