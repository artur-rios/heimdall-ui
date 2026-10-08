// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'data_export_erasure.g.dart';

@JsonSerializable()
class DataExportErasure {
  const DataExportErasure({
    this.isDeleted,
    this.deletedAt,
    this.deletionKind,
    this.anonymisedAt,
    this.erasureRequestedAt,
    this.erasureDueAt,
    this.erasureBlockedReason,
  });

  factory DataExportErasure.fromJson(Map<String, Object?> json) =>
      _$DataExportErasureFromJson(json);

  final bool? isDeleted;
  final DateTime? deletedAt;
  final int? deletionKind;
  final DateTime? anonymisedAt;
  final DateTime? erasureRequestedAt;
  final DateTime? erasureDueAt;
  final String? erasureBlockedReason;

  Map<String, Object?> toJson() => _$DataExportErasureToJson(this);
}
