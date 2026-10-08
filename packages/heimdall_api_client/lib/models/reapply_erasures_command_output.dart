// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'reapply_erasures_command_output.g.dart';

@JsonSerializable()
class ReapplyErasuresCommandOutput {
  const ReapplyErasuresCommandOutput({
    this.anonymised,
    this.alreadyAnonymised,
    this.notFound,
  });

  factory ReapplyErasuresCommandOutput.fromJson(Map<String, Object?> json) =>
      _$ReapplyErasuresCommandOutputFromJson(json);

  final int? anonymised;
  final int? alreadyAnonymised;
  final List<String>? notFound;

  Map<String, Object?> toJson() => _$ReapplyErasuresCommandOutputToJson(this);
}
