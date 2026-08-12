// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'reset_password_command.g.dart';

@JsonSerializable()
class ResetPasswordCommand {
  const ResetPasswordCommand({this.token, this.newPassword});

  factory ResetPasswordCommand.fromJson(Map<String, Object?> json) =>
      _$ResetPasswordCommandFromJson(json);

  final String? token;
  final String? newPassword;

  Map<String, Object?> toJson() => _$ResetPasswordCommandToJson(this);
}
