// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'update_application_command_output.g.dart';

@JsonSerializable()
class UpdateApplicationCommandOutput {
  const UpdateApplicationCommandOutput({
    this.id,
    this.name,
    this.scopeId,
    this.ownerId,
    this.createdAt,
    this.updatedAt,
  });

  factory UpdateApplicationCommandOutput.fromJson(Map<String, Object?> json) =>
      _$UpdateApplicationCommandOutputFromJson(json);

  final String? id;
  final String? name;
  final String? scopeId;
  final String? ownerId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Map<String, Object?> toJson() => _$UpdateApplicationCommandOutputToJson(this);
}
