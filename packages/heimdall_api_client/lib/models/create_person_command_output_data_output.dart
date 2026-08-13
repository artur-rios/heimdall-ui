// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'create_person_command_output.dart';

part 'create_person_command_output_data_output.g.dart';

@JsonSerializable()
class CreatePersonCommandOutputDataOutput {
  const CreatePersonCommandOutputDataOutput({
    this.messages,
    this.errors,
    this.timestamp,
    this.success,
    this.data,
  });

  factory CreatePersonCommandOutputDataOutput.fromJson(
    Map<String, Object?> json,
  ) => _$CreatePersonCommandOutputDataOutputFromJson(json);

  final List<String>? messages;
  final List<String>? errors;
  final DateTime? timestamp;
  final bool? success;
  final CreatePersonCommandOutput? data;

  Map<String, Object?> toJson() =>
      _$CreatePersonCommandOutputDataOutputToJson(this);
}
