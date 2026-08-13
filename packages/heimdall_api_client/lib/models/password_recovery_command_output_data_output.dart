// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'password_recovery_command_output.dart';

part 'password_recovery_command_output_data_output.g.dart';

@JsonSerializable()
class PasswordRecoveryCommandOutputDataOutput {
  const PasswordRecoveryCommandOutputDataOutput({
    this.messages,
    this.errors,
    this.timestamp,
    this.success,
    this.data,
  });

  factory PasswordRecoveryCommandOutputDataOutput.fromJson(
    Map<String, Object?> json,
  ) => _$PasswordRecoveryCommandOutputDataOutputFromJson(json);

  final List<String>? messages;
  final List<String>? errors;
  final DateTime? timestamp;
  final bool? success;
  final PasswordRecoveryCommandOutput? data;

  Map<String, Object?> toJson() =>
      _$PasswordRecoveryCommandOutputDataOutputToJson(this);
}
