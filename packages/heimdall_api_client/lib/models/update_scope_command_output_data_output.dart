// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'update_scope_command_output.dart';

part 'update_scope_command_output_data_output.g.dart';

@JsonSerializable()
class UpdateScopeCommandOutputDataOutput {
  const UpdateScopeCommandOutputDataOutput({
    this.messages,
    this.errors,
    this.timestamp,
    this.success,
    this.data,
  });

  factory UpdateScopeCommandOutputDataOutput.fromJson(
    Map<String, Object?> json,
  ) => _$UpdateScopeCommandOutputDataOutputFromJson(json);

  final List<String>? messages;
  final List<String>? errors;
  final DateTime? timestamp;
  final bool? success;
  final UpdateScopeCommandOutput? data;

  Map<String, Object?> toJson() =>
      _$UpdateScopeCommandOutputDataOutputToJson(this);
}
