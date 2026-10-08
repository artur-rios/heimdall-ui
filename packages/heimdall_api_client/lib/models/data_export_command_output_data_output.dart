// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'data_export_command_output.dart';

part 'data_export_command_output_data_output.g.dart';

@JsonSerializable()
class DataExportCommandOutputDataOutput {
  const DataExportCommandOutputDataOutput({
    this.messages,
    this.errors,
    this.timestamp,
    this.success,
    this.data,
  });

  factory DataExportCommandOutputDataOutput.fromJson(
    Map<String, Object?> json,
  ) => _$DataExportCommandOutputDataOutputFromJson(json);

  final List<String>? messages;
  final List<String>? errors;
  final DateTime? timestamp;
  final bool? success;
  final DataExportCommandOutput? data;

  Map<String, Object?> toJson() =>
      _$DataExportCommandOutputDataOutputToJson(this);
}
