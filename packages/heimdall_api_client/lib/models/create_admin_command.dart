// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'create_admin_command.g.dart';

@JsonSerializable()
class CreateAdminCommand {
  const CreateAdminCommand({this.name, this.email, this.password, this.role});

  factory CreateAdminCommand.fromJson(Map<String, Object?> json) =>
      _$CreateAdminCommandFromJson(json);

  final String? name;
  final String? email;
  final String? password;
  final int? role;

  Map<String, Object?> toJson() => _$CreateAdminCommandToJson(this);
}
