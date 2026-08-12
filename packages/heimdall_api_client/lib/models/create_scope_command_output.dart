// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'create_scope_command_output.g.dart';

@JsonSerializable()
class CreateScopeCommandOutput {
  const CreateScopeCommandOutput({
    this.id,
    this.name,
    this.description,
    this.googleSignInEnabled,
    this.ownerIds,
    this.createdAt,
  });

  factory CreateScopeCommandOutput.fromJson(Map<String, Object?> json) =>
      _$CreateScopeCommandOutputFromJson(json);

  final String? id;
  final String? name;
  final String? description;
  final bool? googleSignInEnabled;
  final List<String>? ownerIds;
  final DateTime? createdAt;

  Map<String, Object?> toJson() => _$CreateScopeCommandOutputToJson(this);
}
