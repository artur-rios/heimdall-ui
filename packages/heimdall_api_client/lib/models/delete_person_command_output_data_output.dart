// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'delete_person_command_output.dart';

part 'delete_person_command_output_data_output.g.dart';

@JsonSerializable()
class DeletePersonCommandOutputDataOutput {
  const DeletePersonCommandOutputDataOutput({
    this.messages,
    this.errors,
    this.timestamp,
    this.success,
    this.data,
  });

  factory DeletePersonCommandOutputDataOutput.fromJson(
    Map<String, Object?> json,
  ) => _$DeletePersonCommandOutputDataOutputFromJson(json);

  final List<String>? messages;
  final List<String>? errors;
  final DateTime? timestamp;
  final bool? success;
  final DeletePersonCommandOutput? data;

  Map<String, Object?> toJson() =>
      _$DeletePersonCommandOutputDataOutputToJson(this);
}
