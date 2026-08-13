// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'add_scope_owner_command_output.dart';

part 'add_scope_owner_command_output_data_output.g.dart';

@JsonSerializable()
class AddScopeOwnerCommandOutputDataOutput {
  const AddScopeOwnerCommandOutputDataOutput({
    this.messages,
    this.errors,
    this.timestamp,
    this.success,
    this.data,
  });

  factory AddScopeOwnerCommandOutputDataOutput.fromJson(
    Map<String, Object?> json,
  ) => _$AddScopeOwnerCommandOutputDataOutputFromJson(json);

  final List<String>? messages;
  final List<String>? errors;
  final DateTime? timestamp;
  final bool? success;
  final AddScopeOwnerCommandOutput? data;

  Map<String, Object?> toJson() =>
      _$AddScopeOwnerCommandOutputDataOutputToJson(this);
}
