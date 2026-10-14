// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'request_erasure_command_output.g.dart';

@JsonSerializable()
class RequestErasureCommandOutput {
  const RequestErasureCommandOutput({
    this.id,
    this.requestedAt,
    this.dueAt,
    this.blocked,
    this.blockedReason,
    this.restrictionLifted,
  });

  factory RequestErasureCommandOutput.fromJson(Map<String, Object?> json) =>
      _$RequestErasureCommandOutputFromJson(json);

  final String? id;
  final DateTime? requestedAt;
  final DateTime? dueAt;
  final bool? blocked;
  final String? blockedReason;
  final bool? restrictionLifted;

  Map<String, Object?> toJson() => _$RequestErasureCommandOutputToJson(this);
}
