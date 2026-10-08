// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'restrict_processing_command.g.dart';

@JsonSerializable()
class RestrictProcessingCommand {
  const RestrictProcessingCommand({this.ground});

  factory RestrictProcessingCommand.fromJson(Map<String, Object?> json) =>
      _$RestrictProcessingCommandFromJson(json);

  final int? ground;

  Map<String, Object?> toJson() => _$RestrictProcessingCommandToJson(this);
}
