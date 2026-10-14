// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'register_command_output.dart';

part 'register_command_output_data_output.g.dart';

@JsonSerializable()
class RegisterCommandOutputDataOutput {
  const RegisterCommandOutputDataOutput({
    this.messages,
    this.errors,
    this.timestamp,
    this.success,
    this.data,
  });

  factory RegisterCommandOutputDataOutput.fromJson(Map<String, Object?> json) =>
      _$RegisterCommandOutputDataOutputFromJson(json);

  final List<String>? messages;
  final List<String>? errors;
  final DateTime? timestamp;
  final bool? success;
  final RegisterCommandOutput? data;

  Map<String, Object?> toJson() =>
      _$RegisterCommandOutputDataOutputToJson(this);
}
