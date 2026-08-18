// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'two_factor_status_output.dart';

part 'two_factor_status_output_data_output.g.dart';

@JsonSerializable()
class TwoFactorStatusOutputDataOutput {
  const TwoFactorStatusOutputDataOutput({
    this.messages,
    this.errors,
    this.timestamp,
    this.success,
    this.data,
  });

  factory TwoFactorStatusOutputDataOutput.fromJson(Map<String, Object?> json) =>
      _$TwoFactorStatusOutputDataOutputFromJson(json);

  final List<String>? messages;
  final List<String>? errors;
  final DateTime? timestamp;
  final bool? success;
  final TwoFactorStatusOutput? data;

  Map<String, Object?> toJson() =>
      _$TwoFactorStatusOutputDataOutputToJson(this);
}
