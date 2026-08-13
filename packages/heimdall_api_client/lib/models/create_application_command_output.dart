// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'create_application_command_output.g.dart';

@JsonSerializable()
class CreateApplicationCommandOutput {
  const CreateApplicationCommandOutput({
    this.id,
    this.name,
    this.scopeId,
    this.ownerId,
    this.createdAt,
  });

  factory CreateApplicationCommandOutput.fromJson(Map<String, Object?> json) =>
      _$CreateApplicationCommandOutputFromJson(json);

  final String? id;
  final String? name;
  final String? scopeId;
  final String? ownerId;
  final DateTime? createdAt;

  Map<String, Object?> toJson() => _$CreateApplicationCommandOutputToJson(this);
}
