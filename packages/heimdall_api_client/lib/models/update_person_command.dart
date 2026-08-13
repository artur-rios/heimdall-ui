// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'update_person_command.g.dart';

@JsonSerializable()
class UpdatePersonCommand {
  const UpdatePersonCommand({this.name, this.email, this.roleId});

  factory UpdatePersonCommand.fromJson(Map<String, Object?> json) =>
      _$UpdatePersonCommandFromJson(json);

  final String? name;
  final String? email;
  final int? roleId;

  Map<String, Object?> toJson() => _$UpdatePersonCommandToJson(this);
}
