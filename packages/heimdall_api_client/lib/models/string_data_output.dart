// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'string_data_output.g.dart';

@JsonSerializable()
class StringDataOutput {
  const StringDataOutput({
    this.messages,
    this.errors,
    this.timestamp,
    this.success,
    this.data,
  });

  factory StringDataOutput.fromJson(Map<String, Object?> json) =>
      _$StringDataOutputFromJson(json);

  final List<String>? messages;
  final List<String>? errors;
  final DateTime? timestamp;
  final bool? success;
  final String? data;

  Map<String, Object?> toJson() => _$StringDataOutputToJson(this);
}
