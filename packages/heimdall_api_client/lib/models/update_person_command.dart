// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'update_person_command.g.dart';

@JsonSerializable()
class UpdatePersonCommand {
  const UpdatePersonCommand({
    this.id,
    this.name,
    this.email,
    this.roleId,
    this.actingPersonId,
    this.actingRole,
  });

  factory UpdatePersonCommand.fromJson(Map<String, Object?> json) =>
      _$UpdatePersonCommandFromJson(json);

  final String? id;
  final String? name;
  final String? email;
  final int? roleId;
  final String? actingPersonId;
  final int? actingRole;

  Map<String, Object?> toJson() => _$UpdatePersonCommandToJson(this);
}
