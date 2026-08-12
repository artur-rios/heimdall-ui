// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'google_user_output.dart';

part 'google_user_output_data_output.g.dart';

@JsonSerializable()
class GoogleUserOutputDataOutput {
  const GoogleUserOutputDataOutput({
    this.messages,
    this.errors,
    this.timestamp,
    this.success,
    this.data,
  });

  factory GoogleUserOutputDataOutput.fromJson(Map<String, Object?> json) =>
      _$GoogleUserOutputDataOutputFromJson(json);

  final List<String>? messages;
  final List<String>? errors;
  final DateTime? timestamp;
  final bool? success;
  final GoogleUserOutput? data;

  Map<String, Object?> toJson() => _$GoogleUserOutputDataOutputToJson(this);
}
