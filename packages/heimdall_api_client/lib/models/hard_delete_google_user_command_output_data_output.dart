// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'hard_delete_google_user_command_output.dart';

part 'hard_delete_google_user_command_output_data_output.g.dart';

@JsonSerializable()
class HardDeleteGoogleUserCommandOutputDataOutput {
  const HardDeleteGoogleUserCommandOutputDataOutput({
    this.messages,
    this.errors,
    this.timestamp,
    this.success,
    this.data,
  });

  factory HardDeleteGoogleUserCommandOutputDataOutput.fromJson(
    Map<String, Object?> json,
  ) => _$HardDeleteGoogleUserCommandOutputDataOutputFromJson(json);

  final List<String>? messages;
  final List<String>? errors;
  final DateTime? timestamp;
  final bool? success;
  final HardDeleteGoogleUserCommandOutput? data;

  Map<String, Object?> toJson() =>
      _$HardDeleteGoogleUserCommandOutputDataOutputToJson(this);
}
