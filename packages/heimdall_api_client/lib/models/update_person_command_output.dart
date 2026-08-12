// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'update_person_command_output.g.dart';

@JsonSerializable()
class UpdatePersonCommandOutput {
  const UpdatePersonCommandOutput({
    this.id,
    this.name,
    this.email,
    this.role,
    this.emailVerified,
    this.scopeId,
    this.ownedScopeIds,
    this.createdAt,
    this.updatedAt,
  });

  factory UpdatePersonCommandOutput.fromJson(Map<String, Object?> json) =>
      _$UpdatePersonCommandOutputFromJson(json);

  final String? id;
  final String? name;
  final String? email;
  final int? role;
  final bool? emailVerified;
  final String? scopeId;
  final List<String>? ownedScopeIds;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Map<String, Object?> toJson() => _$UpdatePersonCommandOutputToJson(this);
}
