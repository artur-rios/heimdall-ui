// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'hard_delete_scope_permission_command_output.dart';

part 'hard_delete_scope_permission_command_output_data_output.g.dart';

@JsonSerializable()
class HardDeleteScopePermissionCommandOutputDataOutput {
  const HardDeleteScopePermissionCommandOutputDataOutput({
    this.messages,
    this.errors,
    this.timestamp,
    this.success,
    this.data,
  });

  factory HardDeleteScopePermissionCommandOutputDataOutput.fromJson(
    Map<String, Object?> json,
  ) => _$HardDeleteScopePermissionCommandOutputDataOutputFromJson(json);

  final List<String>? messages;
  final List<String>? errors;
  final DateTime? timestamp;
  final bool? success;
  final HardDeleteScopePermissionCommandOutput? data;

  Map<String, Object?> toJson() =>
      _$HardDeleteScopePermissionCommandOutputDataOutputToJson(this);
}
