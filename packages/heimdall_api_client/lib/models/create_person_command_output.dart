// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'create_person_command_output.g.dart';

@JsonSerializable()
class CreatePersonCommandOutput {
  const CreatePersonCommandOutput({
    this.id,
    this.name,
    this.email,
    this.role,
    this.emailVerified,
    this.scopeId,
    this.createdAt,
  });

  factory CreatePersonCommandOutput.fromJson(Map<String, Object?> json) =>
      _$CreatePersonCommandOutputFromJson(json);

  final String? id;
  final String? name;
  final String? email;
  final int? role;
  final bool? emailVerified;
  final String? scopeId;
  final DateTime? createdAt;

  Map<String, Object?> toJson() => _$CreatePersonCommandOutputToJson(this);
}
