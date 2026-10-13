// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'register_command.g.dart';

@JsonSerializable()
class RegisterCommand {
  const RegisterCommand({this.name, this.email, this.password, this.scopeId});

  factory RegisterCommand.fromJson(Map<String, Object?> json) =>
      _$RegisterCommandFromJson(json);

  final String? name;
  final String? email;
  final String? password;
  final String? scopeId;

  Map<String, Object?> toJson() => _$RegisterCommandToJson(this);
}
