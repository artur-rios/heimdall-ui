// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'create_scope_permission_command_output.g.dart';

@JsonSerializable()
class CreateScopePermissionCommandOutput {
  const CreateScopePermissionCommandOutput({
    this.id,
    this.name,
    this.description,
    this.includeAsJwtClaim,
    this.scopeId,
    this.createdAt,
  });

  factory CreateScopePermissionCommandOutput.fromJson(
    Map<String, Object?> json,
  ) => _$CreateScopePermissionCommandOutputFromJson(json);

  final String? id;
  final String? name;
  final String? description;
  final bool? includeAsJwtClaim;
  final String? scopeId;
  final DateTime? createdAt;

  Map<String, Object?> toJson() =>
      _$CreateScopePermissionCommandOutputToJson(this);
}
