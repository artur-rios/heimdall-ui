// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'health_check_output.dart';

part 'health_check_output_data_output.g.dart';

@JsonSerializable()
class HealthCheckOutputDataOutput {
  const HealthCheckOutputDataOutput({
    this.messages,
    this.errors,
    this.timestamp,
    this.success,
    this.data,
  });

  factory HealthCheckOutputDataOutput.fromJson(Map<String, Object?> json) =>
      _$HealthCheckOutputDataOutputFromJson(json);

  final List<String>? messages;
  final List<String>? errors;
  final DateTime? timestamp;
  final bool? success;
  final HealthCheckOutput? data;

  Map<String, Object?> toJson() => _$HealthCheckOutputDataOutputToJson(this);
}
