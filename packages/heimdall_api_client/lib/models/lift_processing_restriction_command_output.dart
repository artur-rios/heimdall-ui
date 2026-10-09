// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'lift_processing_restriction_command_output.g.dart';

@JsonSerializable()
class LiftProcessingRestrictionCommandOutput {
  const LiftProcessingRestrictionCommandOutput({
    this.id,
    this.liftedAt,
    this.subjectNotified,
  });

  factory LiftProcessingRestrictionCommandOutput.fromJson(
    Map<String, Object?> json,
  ) => _$LiftProcessingRestrictionCommandOutputFromJson(json);

  final String? id;
  final DateTime? liftedAt;
  final bool? subjectNotified;

  Map<String, Object?> toJson() =>
      _$LiftProcessingRestrictionCommandOutputToJson(this);
}
