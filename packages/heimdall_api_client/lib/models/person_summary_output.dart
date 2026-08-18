// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'person_summary_output.g.dart';

@JsonSerializable()
class PersonSummaryOutput {
  const PersonSummaryOutput({this.id, this.name, this.email});

  factory PersonSummaryOutput.fromJson(Map<String, Object?> json) =>
      _$PersonSummaryOutputFromJson(json);

  final String? id;
  final String? name;
  final String? email;

  Map<String, Object?> toJson() => _$PersonSummaryOutputToJson(this);
}
