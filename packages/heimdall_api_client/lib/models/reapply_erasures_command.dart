// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'reapply_erasures_command.g.dart';

@JsonSerializable()
class ReapplyErasuresCommand {
  const ReapplyErasuresCommand({this.subjectIds});

  factory ReapplyErasuresCommand.fromJson(Map<String, Object?> json) =>
      _$ReapplyErasuresCommandFromJson(json);

  final List<String>? subjectIds;

  Map<String, Object?> toJson() => _$ReapplyErasuresCommandToJson(this);
}
