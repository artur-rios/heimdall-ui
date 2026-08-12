// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'regenerate_recovery_codes_command_output.dart';

part 'regenerate_recovery_codes_command_output_data_output.g.dart';

@JsonSerializable()
class RegenerateRecoveryCodesCommandOutputDataOutput {
  const RegenerateRecoveryCodesCommandOutputDataOutput({
    this.messages,
    this.errors,
    this.timestamp,
    this.success,
    this.data,
  });

  factory RegenerateRecoveryCodesCommandOutputDataOutput.fromJson(
    Map<String, Object?> json,
  ) => _$RegenerateRecoveryCodesCommandOutputDataOutputFromJson(json);

  final List<String>? messages;
  final List<String>? errors;
  final DateTime? timestamp;
  final bool? success;
  final RegenerateRecoveryCodesCommandOutput? data;

  Map<String, Object?> toJson() =>
      _$RegenerateRecoveryCodesCommandOutputDataOutputToJson(this);
}
