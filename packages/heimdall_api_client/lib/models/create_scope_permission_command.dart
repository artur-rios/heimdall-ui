// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'create_scope_permission_command.g.dart';

@JsonSerializable()
class CreateScopePermissionCommand {
  const CreateScopePermissionCommand({
    this.scopeId,
    this.name,
    this.description,
    this.includeAsJwtClaim,
    this.actingPersonId,
    this.actingRole,
  });

  factory CreateScopePermissionCommand.fromJson(Map<String, Object?> json) =>
      _$CreateScopePermissionCommandFromJson(json);

  final String? scopeId;
  final String? name;
  final String? description;
  final bool? includeAsJwtClaim;
  final String? actingPersonId;
  final int? actingRole;

  Map<String, Object?> toJson() => _$CreateScopePermissionCommandToJson(this);
}
