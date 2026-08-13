// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'confirm_two_factor_auth_command_output.g.dart';

@JsonSerializable()
class ConfirmTwoFactorAuthCommandOutput {
  const ConfirmTwoFactorAuthCommandOutput({this.enabled, this.recoveryCodes});

  factory ConfirmTwoFactorAuthCommandOutput.fromJson(
    Map<String, Object?> json,
  ) => _$ConfirmTwoFactorAuthCommandOutputFromJson(json);

  final bool? enabled;
  final List<String>? recoveryCodes;

  Map<String, Object?> toJson() =>
      _$ConfirmTwoFactorAuthCommandOutputToJson(this);
}
