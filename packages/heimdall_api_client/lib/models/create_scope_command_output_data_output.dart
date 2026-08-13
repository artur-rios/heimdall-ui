// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'create_scope_command_output.dart';

part 'create_scope_command_output_data_output.g.dart';

@JsonSerializable()
class CreateScopeCommandOutputDataOutput {
  const CreateScopeCommandOutputDataOutput({
    this.messages,
    this.errors,
    this.timestamp,
    this.success,
    this.data,
  });

  factory CreateScopeCommandOutputDataOutput.fromJson(
    Map<String, Object?> json,
  ) => _$CreateScopeCommandOutputDataOutputFromJson(json);

  final List<String>? messages;
  final List<String>? errors;
  final DateTime? timestamp;
  final bool? success;
  final CreateScopeCommandOutput? data;

  Map<String, Object?> toJson() =>
      _$CreateScopeCommandOutputDataOutputToJson(this);
}
