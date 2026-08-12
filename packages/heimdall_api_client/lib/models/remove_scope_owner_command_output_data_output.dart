// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'remove_scope_owner_command_output.dart';

part 'remove_scope_owner_command_output_data_output.g.dart';

@JsonSerializable()
class RemoveScopeOwnerCommandOutputDataOutput {
  const RemoveScopeOwnerCommandOutputDataOutput({
    this.messages,
    this.errors,
    this.timestamp,
    this.success,
    this.data,
  });

  factory RemoveScopeOwnerCommandOutputDataOutput.fromJson(
    Map<String, Object?> json,
  ) => _$RemoveScopeOwnerCommandOutputDataOutputFromJson(json);

  final List<String>? messages;
  final List<String>? errors;
  final DateTime? timestamp;
  final bool? success;
  final RemoveScopeOwnerCommandOutput? data;

  Map<String, Object?> toJson() =>
      _$RemoveScopeOwnerCommandOutputDataOutputToJson(this);
}
