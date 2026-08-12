// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'enable_two_factor_auth_command_output.dart';

part 'enable_two_factor_auth_command_output_data_output.g.dart';

@JsonSerializable()
class EnableTwoFactorAuthCommandOutputDataOutput {
  const EnableTwoFactorAuthCommandOutputDataOutput({
    this.messages,
    this.errors,
    this.timestamp,
    this.success,
    this.data,
  });

  factory EnableTwoFactorAuthCommandOutputDataOutput.fromJson(
    Map<String, Object?> json,
  ) => _$EnableTwoFactorAuthCommandOutputDataOutputFromJson(json);

  final List<String>? messages;
  final List<String>? errors;
  final DateTime? timestamp;
  final bool? success;
  final EnableTwoFactorAuthCommandOutput? data;

  Map<String, Object?> toJson() =>
      _$EnableTwoFactorAuthCommandOutputDataOutputToJson(this);
}
