// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'erasure_request_output.g.dart';

@JsonSerializable()
class ErasureRequestOutput {
  const ErasureRequestOutput({
    this.subjectId,
    this.isGoogleUser,
    this.requestedAt,
    this.dueAt,
    this.overdue,
    this.blockedReason,
  });

  factory ErasureRequestOutput.fromJson(Map<String, Object?> json) =>
      _$ErasureRequestOutputFromJson(json);

  final String? subjectId;
  final bool? isGoogleUser;
  final DateTime? requestedAt;
  final DateTime? dueAt;
  final bool? overdue;
  final String? blockedReason;

  Map<String, Object?> toJson() => _$ErasureRequestOutputToJson(this);
}
