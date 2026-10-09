// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'data_export_application.g.dart';

@JsonSerializable()
class DataExportApplication {
  const DataExportApplication({
    this.id,
    this.name,
    this.scopeId,
    this.isDeleted,
  });

  factory DataExportApplication.fromJson(Map<String, Object?> json) =>
      _$DataExportApplicationFromJson(json);

  final String? id;
  final String? name;
  final String? scopeId;
  final bool? isDeleted;

  Map<String, Object?> toJson() => _$DataExportApplicationToJson(this);
}
