// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'create_scope_owner_command.g.dart';

@JsonSerializable()
class CreateScopeOwnerCommand {
  const CreateScopeOwnerCommand({this.name, this.email, this.password});

  factory CreateScopeOwnerCommand.fromJson(Map<String, Object?> json) =>
      _$CreateScopeOwnerCommandFromJson(json);

  final String? name;
  final String? email;
  final String? password;

  Map<String, Object?> toJson() => _$CreateScopeOwnerCommandToJson(this);
}
