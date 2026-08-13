// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'set_google_sign_in_command_output.dart';

part 'set_google_sign_in_command_output_data_output.g.dart';

@JsonSerializable()
class SetGoogleSignInCommandOutputDataOutput {
  const SetGoogleSignInCommandOutputDataOutput({
    this.messages,
    this.errors,
    this.timestamp,
    this.success,
    this.data,
  });

  factory SetGoogleSignInCommandOutputDataOutput.fromJson(
    Map<String, Object?> json,
  ) => _$SetGoogleSignInCommandOutputDataOutputFromJson(json);

  final List<String>? messages;
  final List<String>? errors;
  final DateTime? timestamp;
  final bool? success;
  final SetGoogleSignInCommandOutput? data;

  Map<String, Object?> toJson() =>
      _$SetGoogleSignInCommandOutputDataOutputToJson(this);
}
