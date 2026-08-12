// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'password_recovery_command.g.dart';

@JsonSerializable()
class PasswordRecoveryCommand {
  const PasswordRecoveryCommand({this.email, this.scopeId});

  factory PasswordRecoveryCommand.fromJson(Map<String, Object?> json) =>
      _$PasswordRecoveryCommandFromJson(json);

  final String? email;
  final String? scopeId;

  Map<String, Object?> toJson() => _$PasswordRecoveryCommandToJson(this);
}
