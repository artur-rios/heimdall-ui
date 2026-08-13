// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'application_output.g.dart';

@JsonSerializable()
class ApplicationOutput {
  const ApplicationOutput({
    this.id,
    this.name,
    this.scopeId,
    this.ownerId,
    this.isDeleted,
    this.createdAt,
    this.updatedAt,
  });

  factory ApplicationOutput.fromJson(Map<String, Object?> json) =>
      _$ApplicationOutputFromJson(json);

  final String? id;
  final String? name;
  final String? scopeId;
  final String? ownerId;
  final bool? isDeleted;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Map<String, Object?> toJson() => _$ApplicationOutputToJson(this);
}
