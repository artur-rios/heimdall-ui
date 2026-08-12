// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'confirm_two_factor_auth_command_output.dart';

part 'confirm_two_factor_auth_command_output_data_output.g.dart';

@JsonSerializable()
class ConfirmTwoFactorAuthCommandOutputDataOutput {
  const ConfirmTwoFactorAuthCommandOutputDataOutput({
    this.messages,
    this.errors,
    this.timestamp,
    this.success,
    this.data,
  });

  factory ConfirmTwoFactorAuthCommandOutputDataOutput.fromJson(
    Map<String, Object?> json,
  ) => _$ConfirmTwoFactorAuthCommandOutputDataOutputFromJson(json);

  final List<String>? messages;
  final List<String>? errors;
  final DateTime? timestamp;
  final bool? success;
  final ConfirmTwoFactorAuthCommandOutput? data;

  Map<String, Object?> toJson() =>
      _$ConfirmTwoFactorAuthCommandOutputDataOutputToJson(this);
}
