// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'update_scope_permission_command.g.dart';

@JsonSerializable()
class UpdateScopePermissionCommand {
  const UpdateScopePermissionCommand({
    this.scopeId,
    this.id,
    this.name,
    this.description,
    this.includeAsJwtClaim,
    this.actingPersonId,
    this.actingRole,
  });

  factory UpdateScopePermissionCommand.fromJson(Map<String, Object?> json) =>
      _$UpdateScopePermissionCommandFromJson(json);

  final String? scopeId;
  final String? id;
  final String? name;
  final String? description;
  final bool? includeAsJwtClaim;
  final String? actingPersonId;
  final int? actingRole;

  Map<String, Object?> toJson() => _$UpdateScopePermissionCommandToJson(this);
}
