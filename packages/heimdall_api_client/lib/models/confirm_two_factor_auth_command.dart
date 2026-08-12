// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'confirm_two_factor_auth_command.g.dart';

@JsonSerializable()
class ConfirmTwoFactorAuthCommand {
  const ConfirmTwoFactorAuthCommand({
    this.appCode,
    this.emailCode,
    this.actingPersonId,
    this.actingRole,
  });

  factory ConfirmTwoFactorAuthCommand.fromJson(Map<String, Object?> json) =>
      _$ConfirmTwoFactorAuthCommandFromJson(json);

  final String? appCode;
  final String? emailCode;
  final String? actingPersonId;
  final int? actingRole;

  Map<String, Object?> toJson() => _$ConfirmTwoFactorAuthCommandToJson(this);
}
