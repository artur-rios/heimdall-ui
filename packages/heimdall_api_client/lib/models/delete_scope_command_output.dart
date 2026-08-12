// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'delete_scope_command_output.g.dart';

@JsonSerializable()
class DeleteScopeCommandOutput {
  const DeleteScopeCommandOutput({
    this.id,
    this.userCount,
    this.googleUserCount,
    this.applicationCount,
  });

  factory DeleteScopeCommandOutput.fromJson(Map<String, Object?> json) =>
      _$DeleteScopeCommandOutputFromJson(json);

  final String? id;
  final int? userCount;
  final int? googleUserCount;
  final int? applicationCount;

  Map<String, Object?> toJson() => _$DeleteScopeCommandOutputToJson(this);
}
