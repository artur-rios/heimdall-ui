// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'set_self_registration_command_output.dart';

part 'set_self_registration_command_output_data_output.g.dart';

@JsonSerializable()
class SetSelfRegistrationCommandOutputDataOutput {
  const SetSelfRegistrationCommandOutputDataOutput({
    this.messages,
    this.errors,
    this.timestamp,
    this.success,
    this.data,
  });

  factory SetSelfRegistrationCommandOutputDataOutput.fromJson(
    Map<String, Object?> json,
  ) => _$SetSelfRegistrationCommandOutputDataOutputFromJson(json);

  final List<String>? messages;
  final List<String>? errors;
  final DateTime? timestamp;
  final bool? success;
  final SetSelfRegistrationCommandOutput? data;

  Map<String, Object?> toJson() =>
      _$SetSelfRegistrationCommandOutputDataOutputToJson(this);
}
