// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'hard_delete_scope_command_output.g.dart';

@JsonSerializable()
class HardDeleteScopeCommandOutput {
  const HardDeleteScopeCommandOutput({
    this.id,
    this.userCount,
    this.googleUserCount,
    this.applicationCount,
    this.scopePermissionCount,
  });

  factory HardDeleteScopeCommandOutput.fromJson(Map<String, Object?> json) =>
      _$HardDeleteScopeCommandOutputFromJson(json);

  final String? id;
  final int? userCount;
  final int? googleUserCount;
  final int? applicationCount;
  final int? scopePermissionCount;

  Map<String, Object?> toJson() => _$HardDeleteScopeCommandOutputToJson(this);
}
