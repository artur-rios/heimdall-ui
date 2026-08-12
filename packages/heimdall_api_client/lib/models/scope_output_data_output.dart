// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'scope_output.dart';

part 'scope_output_data_output.g.dart';

@JsonSerializable()
class ScopeOutputDataOutput {
  const ScopeOutputDataOutput({
    this.messages,
    this.errors,
    this.timestamp,
    this.success,
    this.data,
  });

  factory ScopeOutputDataOutput.fromJson(Map<String, Object?> json) =>
      _$ScopeOutputDataOutputFromJson(json);

  final List<String>? messages;
  final List<String>? errors;
  final DateTime? timestamp;
  final bool? success;
  final ScopeOutput? data;

  Map<String, Object?> toJson() => _$ScopeOutputDataOutputToJson(this);
}
