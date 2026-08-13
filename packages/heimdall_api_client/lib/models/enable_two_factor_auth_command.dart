// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'enable_two_factor_auth_command.g.dart';

@JsonSerializable()
class EnableTwoFactorAuthCommand {
  const EnableTwoFactorAuthCommand({this.methods});

  factory EnableTwoFactorAuthCommand.fromJson(Map<String, Object?> json) =>
      _$EnableTwoFactorAuthCommandFromJson(json);

  final List<String>? methods;

  Map<String, Object?> toJson() => _$EnableTwoFactorAuthCommandToJson(this);
}
