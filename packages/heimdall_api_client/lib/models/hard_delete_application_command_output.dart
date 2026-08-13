// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'hard_delete_application_command_output.g.dart';

@JsonSerializable()
class HardDeleteApplicationCommandOutput {
  const HardDeleteApplicationCommandOutput({this.id});

  factory HardDeleteApplicationCommandOutput.fromJson(
    Map<String, Object?> json,
  ) => _$HardDeleteApplicationCommandOutputFromJson(json);

  final String? id;

  Map<String, Object?> toJson() =>
      _$HardDeleteApplicationCommandOutputToJson(this);
}
