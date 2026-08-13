// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'update_scope_permission_command_output.g.dart';

@JsonSerializable()
class UpdateScopePermissionCommandOutput {
  const UpdateScopePermissionCommandOutput({
    this.id,
    this.name,
    this.description,
    this.includeAsJwtClaim,
    this.scopeId,
    this.createdAt,
    this.updatedAt,
  });

  factory UpdateScopePermissionCommandOutput.fromJson(
    Map<String, Object?> json,
  ) => _$UpdateScopePermissionCommandOutputFromJson(json);

  final String? id;
  final String? name;
  final String? description;
  final bool? includeAsJwtClaim;
  final String? scopeId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Map<String, Object?> toJson() =>
      _$UpdateScopePermissionCommandOutputToJson(this);
}
