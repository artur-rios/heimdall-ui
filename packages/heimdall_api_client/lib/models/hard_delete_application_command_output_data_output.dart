// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'hard_delete_application_command_output.dart';

part 'hard_delete_application_command_output_data_output.g.dart';

@JsonSerializable()
class HardDeleteApplicationCommandOutputDataOutput {
  const HardDeleteApplicationCommandOutputDataOutput({
    this.messages,
    this.errors,
    this.timestamp,
    this.success,
    this.data,
  });

  factory HardDeleteApplicationCommandOutputDataOutput.fromJson(
    Map<String, Object?> json,
  ) => _$HardDeleteApplicationCommandOutputDataOutputFromJson(json);

  final List<String>? messages;
  final List<String>? errors;
  final DateTime? timestamp;
  final bool? success;
  final HardDeleteApplicationCommandOutput? data;

  Map<String, Object?> toJson() =>
      _$HardDeleteApplicationCommandOutputDataOutputToJson(this);
}
