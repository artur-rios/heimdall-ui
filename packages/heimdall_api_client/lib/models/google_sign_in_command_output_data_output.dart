// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'google_sign_in_command_output.dart';

part 'google_sign_in_command_output_data_output.g.dart';

@JsonSerializable()
class GoogleSignInCommandOutputDataOutput {
  const GoogleSignInCommandOutputDataOutput({
    this.messages,
    this.errors,
    this.timestamp,
    this.success,
    this.data,
  });

  factory GoogleSignInCommandOutputDataOutput.fromJson(
    Map<String, Object?> json,
  ) => _$GoogleSignInCommandOutputDataOutputFromJson(json);

  final List<String>? messages;
  final List<String>? errors;
  final DateTime? timestamp;
  final bool? success;
  final GoogleSignInCommandOutput? data;

  Map<String, Object?> toJson() =>
      _$GoogleSignInCommandOutputDataOutputToJson(this);
}
