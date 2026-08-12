// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'create_user_command.g.dart';

@JsonSerializable()
class CreateUserCommand {
  const CreateUserCommand({
    this.scopeId,
    this.name,
    this.email,
    this.password,
    this.actingPersonId,
    this.actingRole,
  });

  factory CreateUserCommand.fromJson(Map<String, Object?> json) =>
      _$CreateUserCommandFromJson(json);

  final String? scopeId;
  final String? name;
  final String? email;
  final String? password;
  final String? actingPersonId;
  final int? actingRole;

  Map<String, Object?> toJson() => _$CreateUserCommandToJson(this);
}
