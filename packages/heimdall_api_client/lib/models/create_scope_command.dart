// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'create_scope_command.g.dart';

@JsonSerializable()
class CreateScopeCommand {
  const CreateScopeCommand({this.name, this.description, this.ownerIds});

  factory CreateScopeCommand.fromJson(Map<String, Object?> json) =>
      _$CreateScopeCommandFromJson(json);

  final String? name;
  final String? description;
  final List<String>? ownerIds;

  Map<String, Object?> toJson() => _$CreateScopeCommandToJson(this);
}
