// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'disable_two_factor_auth_command.g.dart';

@JsonSerializable()
class DisableTwoFactorAuthCommand {
  const DisableTwoFactorAuthCommand({
    this.password,
    this.code,
    this.recoveryCode,
    this.actingPersonId,
    this.actingRole,
  });

  factory DisableTwoFactorAuthCommand.fromJson(Map<String, Object?> json) =>
      _$DisableTwoFactorAuthCommandFromJson(json);

  final String? password;
  final String? code;
  final String? recoveryCode;
  final String? actingPersonId;
  final int? actingRole;

  Map<String, Object?> toJson() => _$DisableTwoFactorAuthCommandToJson(this);
}
