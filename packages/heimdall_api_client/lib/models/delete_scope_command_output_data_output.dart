// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'delete_scope_command_output.dart';

part 'delete_scope_command_output_data_output.g.dart';

@JsonSerializable()
class DeleteScopeCommandOutputDataOutput {
  const DeleteScopeCommandOutputDataOutput({
    this.messages,
    this.errors,
    this.timestamp,
    this.success,
    this.data,
  });

  factory DeleteScopeCommandOutputDataOutput.fromJson(
    Map<String, Object?> json,
  ) => _$DeleteScopeCommandOutputDataOutputFromJson(json);

  final List<String>? messages;
  final List<String>? errors;
  final DateTime? timestamp;
  final bool? success;
  final DeleteScopeCommandOutput? data;

  Map<String, Object?> toJson() =>
      _$DeleteScopeCommandOutputDataOutputToJson(this);
}
