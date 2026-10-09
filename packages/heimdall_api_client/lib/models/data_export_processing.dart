// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'data_export_processing.g.dart';

@JsonSerializable()
class DataExportProcessing {
  const DataExportProcessing({
    this.legalBasis,
    this.legalBasisName,
    this.privacyNoticeVersion,
    this.recordedAt,
  });

  factory DataExportProcessing.fromJson(Map<String, Object?> json) =>
      _$DataExportProcessingFromJson(json);

  final int? legalBasis;
  final String? legalBasisName;
  final String? privacyNoticeVersion;
  final DateTime? recordedAt;

  Map<String, Object?> toJson() => _$DataExportProcessingToJson(this);
}
