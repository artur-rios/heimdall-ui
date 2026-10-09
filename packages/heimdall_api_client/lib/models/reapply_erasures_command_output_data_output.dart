// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'reapply_erasures_command_output.dart';

part 'reapply_erasures_command_output_data_output.g.dart';

@JsonSerializable()
class ReapplyErasuresCommandOutputDataOutput {
  const ReapplyErasuresCommandOutputDataOutput({
    this.messages,
    this.errors,
    this.timestamp,
    this.success,
    this.data,
  });

  factory ReapplyErasuresCommandOutputDataOutput.fromJson(
    Map<String, Object?> json,
  ) => _$ReapplyErasuresCommandOutputDataOutputFromJson(json);

  final List<String>? messages;
  final List<String>? errors;
  final DateTime? timestamp;
  final bool? success;
  final ReapplyErasuresCommandOutput? data;

  Map<String, Object?> toJson() =>
      _$ReapplyErasuresCommandOutputDataOutputToJson(this);
}
