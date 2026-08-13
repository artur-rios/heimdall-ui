// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'update_scope_permission_command.g.dart';

@JsonSerializable()
class UpdateScopePermissionCommand {
  const UpdateScopePermissionCommand({
    this.name,
    this.description,
    this.includeAsJwtClaim,
  });

  factory UpdateScopePermissionCommand.fromJson(Map<String, Object?> json) =>
      _$UpdateScopePermissionCommandFromJson(json);

  final String? name;
  final String? description;
  final bool? includeAsJwtClaim;

  Map<String, Object?> toJson() => _$UpdateScopePermissionCommandToJson(this);
}
