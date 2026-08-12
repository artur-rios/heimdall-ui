// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'reset_password_command_output.dart';

part 'reset_password_command_output_data_output.g.dart';

@JsonSerializable()
class ResetPasswordCommandOutputDataOutput {
  const ResetPasswordCommandOutputDataOutput({
    this.messages,
    this.errors,
    this.timestamp,
    this.success,
    this.data,
  });

  factory ResetPasswordCommandOutputDataOutput.fromJson(
    Map<String, Object?> json,
  ) => _$ResetPasswordCommandOutputDataOutputFromJson(json);

  final List<String>? messages;
  final List<String>? errors;
  final DateTime? timestamp;
  final bool? success;
  final ResetPasswordCommandOutput? data;

  Map<String, Object?> toJson() =>
      _$ResetPasswordCommandOutputDataOutputToJson(this);
}
