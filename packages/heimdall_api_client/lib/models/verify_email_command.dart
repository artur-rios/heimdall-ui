// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'verify_email_command.g.dart';

@JsonSerializable()
class VerifyEmailCommand {
  const VerifyEmailCommand({this.token, this.password});

  factory VerifyEmailCommand.fromJson(Map<String, Object?> json) =>
      _$VerifyEmailCommandFromJson(json);

  final String? token;
  final String? password;

  Map<String, Object?> toJson() => _$VerifyEmailCommandToJson(this);
}
