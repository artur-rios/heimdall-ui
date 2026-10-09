// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'data_export_withheld.g.dart';

@JsonSerializable()
class DataExportWithheld {
  const DataExportWithheld({this.value, this.reason});

  factory DataExportWithheld.fromJson(Map<String, Object?> json) =>
      _$DataExportWithheldFromJson(json);

  final String? value;
  final String? reason;

  Map<String, Object?> toJson() => _$DataExportWithheldToJson(this);
}
