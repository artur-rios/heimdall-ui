// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'lift_processing_restriction_command_output.dart';

part 'lift_processing_restriction_command_output_data_output.g.dart';

@JsonSerializable()
class LiftProcessingRestrictionCommandOutputDataOutput {
  const LiftProcessingRestrictionCommandOutputDataOutput({
    this.messages,
    this.errors,
    this.timestamp,
    this.success,
    this.data,
  });

  factory LiftProcessingRestrictionCommandOutputDataOutput.fromJson(
    Map<String, Object?> json,
  ) => _$LiftProcessingRestrictionCommandOutputDataOutputFromJson(json);

  final List<String>? messages;
  final List<String>? errors;
  final DateTime? timestamp;
  final bool? success;
  final LiftProcessingRestrictionCommandOutput? data;

  Map<String, Object?> toJson() =>
      _$LiftProcessingRestrictionCommandOutputDataOutputToJson(this);
}
