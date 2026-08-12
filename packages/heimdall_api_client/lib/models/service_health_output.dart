// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'service_health_output.g.dart';

@JsonSerializable()
class ServiceHealthOutput {
  const ServiceHealthOutput({this.name, this.status});

  factory ServiceHealthOutput.fromJson(Map<String, Object?> json) =>
      _$ServiceHealthOutputFromJson(json);

  final String? name;
  final String? status;

  Map<String, Object?> toJson() => _$ServiceHealthOutputToJson(this);
}
