// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'data_export_retention.g.dart';

@JsonSerializable()
class DataExportRetention {
  const DataExportRetention({this.category, this.period});

  factory DataExportRetention.fromJson(Map<String, Object?> json) =>
      _$DataExportRetentionFromJson(json);

  final String? category;
  final String? period;

  Map<String, Object?> toJson() => _$DataExportRetentionToJson(this);
}
