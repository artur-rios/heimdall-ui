// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'hard_delete_scope_permission_command_output.g.dart';

@JsonSerializable()
class HardDeleteScopePermissionCommandOutput {
  const HardDeleteScopePermissionCommandOutput({this.id});

  factory HardDeleteScopePermissionCommandOutput.fromJson(
    Map<String, Object?> json,
  ) => _$HardDeleteScopePermissionCommandOutputFromJson(json);

  final String? id;

  Map<String, Object?> toJson() =>
      _$HardDeleteScopePermissionCommandOutputToJson(this);
}
