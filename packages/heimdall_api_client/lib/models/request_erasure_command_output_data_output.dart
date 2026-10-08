// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'request_erasure_command_output.dart';

part 'request_erasure_command_output_data_output.g.dart';

@JsonSerializable()
class RequestErasureCommandOutputDataOutput {
  const RequestErasureCommandOutputDataOutput({
    this.messages,
    this.errors,
    this.timestamp,
    this.success,
    this.data,
  });

  factory RequestErasureCommandOutputDataOutput.fromJson(
    Map<String, Object?> json,
  ) => _$RequestErasureCommandOutputDataOutputFromJson(json);

  final List<String>? messages;
  final List<String>? errors;
  final DateTime? timestamp;
  final bool? success;
  final RequestErasureCommandOutput? data;

  Map<String, Object?> toJson() =>
      _$RequestErasureCommandOutputDataOutputToJson(this);
}
