// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'restrict_processing_command_output.dart';

part 'restrict_processing_command_output_data_output.g.dart';

@JsonSerializable()
class RestrictProcessingCommandOutputDataOutput {
  const RestrictProcessingCommandOutputDataOutput({
    this.messages,
    this.errors,
    this.timestamp,
    this.success,
    this.data,
  });

  factory RestrictProcessingCommandOutputDataOutput.fromJson(
    Map<String, Object?> json,
  ) => _$RestrictProcessingCommandOutputDataOutputFromJson(json);

  final List<String>? messages;
  final List<String>? errors;
  final DateTime? timestamp;
  final bool? success;
  final RestrictProcessingCommandOutput? data;

  Map<String, Object?> toJson() =>
      _$RestrictProcessingCommandOutputDataOutputToJson(this);
}
