// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'delete_scope_permission_command_output.g.dart';

@JsonSerializable()
class DeleteScopePermissionCommandOutput {
  const DeleteScopePermissionCommandOutput({this.id, this.alreadyDeleted});

  factory DeleteScopePermissionCommandOutput.fromJson(
    Map<String, Object?> json,
  ) => _$DeleteScopePermissionCommandOutputFromJson(json);

  final String? id;
  final bool? alreadyDeleted;

  Map<String, Object?> toJson() =>
      _$DeleteScopePermissionCommandOutputToJson(this);
}
