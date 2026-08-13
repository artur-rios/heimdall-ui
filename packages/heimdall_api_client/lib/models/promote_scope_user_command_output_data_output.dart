// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'promote_scope_user_command_output.dart';

part 'promote_scope_user_command_output_data_output.g.dart';

@JsonSerializable()
class PromoteScopeUserCommandOutputDataOutput {
  const PromoteScopeUserCommandOutputDataOutput({
    this.messages,
    this.errors,
    this.timestamp,
    this.success,
    this.data,
  });

  factory PromoteScopeUserCommandOutputDataOutput.fromJson(
    Map<String, Object?> json,
  ) => _$PromoteScopeUserCommandOutputDataOutputFromJson(json);

  final List<String>? messages;
  final List<String>? errors;
  final DateTime? timestamp;
  final bool? success;
  final PromoteScopeUserCommandOutput? data;

  Map<String, Object?> toJson() =>
      _$PromoteScopeUserCommandOutputDataOutputToJson(this);
}
