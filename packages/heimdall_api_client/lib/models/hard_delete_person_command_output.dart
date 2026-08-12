// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'hard_delete_person_command_output.g.dart';

@JsonSerializable()
class HardDeletePersonCommandOutput {
  const HardDeletePersonCommandOutput({
    this.id,
    this.deletedApplicationCount,
    this.deletedTokenCount,
  });

  factory HardDeletePersonCommandOutput.fromJson(Map<String, Object?> json) =>
      _$HardDeletePersonCommandOutputFromJson(json);

  final String? id;
  final int? deletedApplicationCount;
  final int? deletedTokenCount;

  Map<String, Object?> toJson() => _$HardDeletePersonCommandOutputToJson(this);
}
