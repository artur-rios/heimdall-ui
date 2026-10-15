// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'application_token_check_output.dart';

part 'application_token_check_output_data_output.g.dart';

@JsonSerializable()
class ApplicationTokenCheckOutputDataOutput {
  const ApplicationTokenCheckOutputDataOutput({
    this.messages,
    this.errors,
    this.timestamp,
    this.success,
    this.data,
  });

  factory ApplicationTokenCheckOutputDataOutput.fromJson(
    Map<String, Object?> json,
  ) => _$ApplicationTokenCheckOutputDataOutputFromJson(json);

  final List<String>? messages;
  final List<String>? errors;
  final DateTime? timestamp;
  final bool? success;
  final ApplicationTokenCheckOutput? data;

  Map<String, Object?> toJson() =>
      _$ApplicationTokenCheckOutputDataOutputToJson(this);
}
