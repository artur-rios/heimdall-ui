// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'delete_person_command_output.g.dart';

@JsonSerializable()
class DeletePersonCommandOutput {
  const DeletePersonCommandOutput({this.id, this.alreadyDeleted});

  factory DeletePersonCommandOutput.fromJson(Map<String, Object?> json) =>
      _$DeletePersonCommandOutputFromJson(json);

  final String? id;
  final bool? alreadyDeleted;

  Map<String, Object?> toJson() => _$DeletePersonCommandOutputToJson(this);
}
