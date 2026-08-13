// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'update_scope_command.g.dart';

@JsonSerializable()
class UpdateScopeCommand {
  const UpdateScopeCommand({this.name, this.description});

  factory UpdateScopeCommand.fromJson(Map<String, Object?> json) =>
      _$UpdateScopeCommandFromJson(json);

  final String? name;
  final String? description;

  Map<String, Object?> toJson() => _$UpdateScopeCommandToJson(this);
}
