// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'service_health_output.dart';

part 'health_check_output.g.dart';

@JsonSerializable()
class HealthCheckOutput {
  const HealthCheckOutput({this.status, this.services});

  factory HealthCheckOutput.fromJson(Map<String, Object?> json) =>
      _$HealthCheckOutputFromJson(json);

  final String? status;
  final List<ServiceHealthOutput>? services;

  Map<String, Object?> toJson() => _$HealthCheckOutputToJson(this);
}
