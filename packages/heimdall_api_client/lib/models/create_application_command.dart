// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'create_application_command.g.dart';

@JsonSerializable()
class CreateApplicationCommand {
  const CreateApplicationCommand({this.name, this.ownerId});

  factory CreateApplicationCommand.fromJson(Map<String, Object?> json) =>
      _$CreateApplicationCommandFromJson(json);

  final String? name;
  final String? ownerId;

  Map<String, Object?> toJson() => _$CreateApplicationCommandToJson(this);
}
