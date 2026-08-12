// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'hard_delete_scope_command_output.dart';

part 'hard_delete_scope_command_output_data_output.g.dart';

@JsonSerializable()
class HardDeleteScopeCommandOutputDataOutput {
  const HardDeleteScopeCommandOutputDataOutput({
    this.messages,
    this.errors,
    this.timestamp,
    this.success,
    this.data,
  });

  factory HardDeleteScopeCommandOutputDataOutput.fromJson(
    Map<String, Object?> json,
  ) => _$HardDeleteScopeCommandOutputDataOutputFromJson(json);

  final List<String>? messages;
  final List<String>? errors;
  final DateTime? timestamp;
  final bool? success;
  final HardDeleteScopeCommandOutput? data;

  Map<String, Object?> toJson() =>
      _$HardDeleteScopeCommandOutputDataOutputToJson(this);
}
