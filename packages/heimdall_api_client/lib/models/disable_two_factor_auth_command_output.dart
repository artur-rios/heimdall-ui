// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'disable_two_factor_auth_command_output.g.dart';

@JsonSerializable()
class DisableTwoFactorAuthCommandOutput {
  const DisableTwoFactorAuthCommandOutput({this.disabled});

  factory DisableTwoFactorAuthCommandOutput.fromJson(
    Map<String, Object?> json,
  ) => _$DisableTwoFactorAuthCommandOutputFromJson(json);

  final bool? disabled;

  Map<String, Object?> toJson() =>
      _$DisableTwoFactorAuthCommandOutputToJson(this);
}
