// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'discard_pending_registration_command_output.dart';

part 'discard_pending_registration_command_output_data_output.g.dart';

@JsonSerializable()
class DiscardPendingRegistrationCommandOutputDataOutput {
  const DiscardPendingRegistrationCommandOutputDataOutput({
    this.messages,
    this.errors,
    this.timestamp,
    this.success,
    this.data,
  });

  factory DiscardPendingRegistrationCommandOutputDataOutput.fromJson(
    Map<String, Object?> json,
  ) => _$DiscardPendingRegistrationCommandOutputDataOutputFromJson(json);

  final List<String>? messages;
  final List<String>? errors;
  final DateTime? timestamp;
  final bool? success;
  final DiscardPendingRegistrationCommandOutput? data;

  Map<String, Object?> toJson() =>
      _$DiscardPendingRegistrationCommandOutputDataOutputToJson(this);
}
