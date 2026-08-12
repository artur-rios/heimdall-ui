// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'verify_two_factor_auth_command_output.g.dart';

@JsonSerializable()
class VerifyTwoFactorAuthCommandOutput {
  const VerifyTwoFactorAuthCommandOutput({this.token, this.expiresAt});

  factory VerifyTwoFactorAuthCommandOutput.fromJson(
    Map<String, Object?> json,
  ) => _$VerifyTwoFactorAuthCommandOutputFromJson(json);

  final String? token;
  final DateTime? expiresAt;

  Map<String, Object?> toJson() =>
      _$VerifyTwoFactorAuthCommandOutputToJson(this);
}
