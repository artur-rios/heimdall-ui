// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'verify_email_command_output.dart';

part 'verify_email_command_output_data_output.g.dart';

@JsonSerializable()
class VerifyEmailCommandOutputDataOutput {
  const VerifyEmailCommandOutputDataOutput({
    this.messages,
    this.errors,
    this.timestamp,
    this.success,
    this.data,
  });

  factory VerifyEmailCommandOutputDataOutput.fromJson(
    Map<String, Object?> json,
  ) => _$VerifyEmailCommandOutputDataOutputFromJson(json);

  final List<String>? messages;
  final List<String>? errors;
  final DateTime? timestamp;
  final bool? success;
  final VerifyEmailCommandOutput? data;

  Map<String, Object?> toJson() =>
      _$VerifyEmailCommandOutputDataOutputToJson(this);
}
