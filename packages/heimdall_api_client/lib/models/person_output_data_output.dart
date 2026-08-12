// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'person_output.dart';

part 'person_output_data_output.g.dart';

@JsonSerializable()
class PersonOutputDataOutput {
  const PersonOutputDataOutput({
    this.messages,
    this.errors,
    this.timestamp,
    this.success,
    this.data,
  });

  factory PersonOutputDataOutput.fromJson(Map<String, Object?> json) =>
      _$PersonOutputDataOutputFromJson(json);

  final List<String>? messages;
  final List<String>? errors;
  final DateTime? timestamp;
  final bool? success;
  final PersonOutput? data;

  Map<String, Object?> toJson() => _$PersonOutputDataOutputToJson(this);
}
