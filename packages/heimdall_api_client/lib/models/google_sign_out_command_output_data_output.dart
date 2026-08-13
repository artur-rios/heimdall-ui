// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'google_sign_out_command_output.dart';

part 'google_sign_out_command_output_data_output.g.dart';

@JsonSerializable()
class GoogleSignOutCommandOutputDataOutput {
  const GoogleSignOutCommandOutputDataOutput({
    this.messages,
    this.errors,
    this.timestamp,
    this.success,
    this.data,
  });

  factory GoogleSignOutCommandOutputDataOutput.fromJson(
    Map<String, Object?> json,
  ) => _$GoogleSignOutCommandOutputDataOutputFromJson(json);

  final List<String>? messages;
  final List<String>? errors;
  final DateTime? timestamp;
  final bool? success;
  final GoogleSignOutCommandOutput? data;

  Map<String, Object?> toJson() =>
      _$GoogleSignOutCommandOutputDataOutputToJson(this);
}
