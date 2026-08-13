// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'scope_permission_output.dart';

part 'scope_permission_output_data_output.g.dart';

@JsonSerializable()
class ScopePermissionOutputDataOutput {
  const ScopePermissionOutputDataOutput({
    this.messages,
    this.errors,
    this.timestamp,
    this.success,
    this.data,
  });

  factory ScopePermissionOutputDataOutput.fromJson(Map<String, Object?> json) =>
      _$ScopePermissionOutputDataOutputFromJson(json);

  final List<String>? messages;
  final List<String>? errors;
  final DateTime? timestamp;
  final bool? success;
  final ScopePermissionOutput? data;

  Map<String, Object?> toJson() =>
      _$ScopePermissionOutputDataOutputToJson(this);
}
