// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'restrict_processing_command_output.g.dart';

@JsonSerializable()
class RestrictProcessingCommandOutput {
  const RestrictProcessingCommandOutput({
    this.id,
    this.restrictedAt,
    this.ground,
  });

  factory RestrictProcessingCommandOutput.fromJson(Map<String, Object?> json) =>
      _$RestrictProcessingCommandOutputFromJson(json);

  final String? id;
  final DateTime? restrictedAt;
  final int? ground;

  Map<String, Object?> toJson() =>
      _$RestrictProcessingCommandOutputToJson(this);
}
