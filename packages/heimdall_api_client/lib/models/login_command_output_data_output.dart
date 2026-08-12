// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'login_command_output.dart';

part 'login_command_output_data_output.g.dart';

@JsonSerializable()
class LoginCommandOutputDataOutput {
  const LoginCommandOutputDataOutput({
    this.messages,
    this.errors,
    this.timestamp,
    this.success,
    this.data,
  });

  factory LoginCommandOutputDataOutput.fromJson(Map<String, Object?> json) =>
      _$LoginCommandOutputDataOutputFromJson(json);

  final List<String>? messages;
  final List<String>? errors;
  final DateTime? timestamp;
  final bool? success;
  final LoginCommandOutput? data;

  Map<String, Object?> toJson() => _$LoginCommandOutputDataOutputToJson(this);
}
