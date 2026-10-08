// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'data_export_source.g.dart';

@JsonSerializable()
class DataExportSource {
  const DataExportSource({this.name, this.provides, this.dataSentThere});

  factory DataExportSource.fromJson(Map<String, Object?> json) =>
      _$DataExportSourceFromJson(json);

  final String? name;
  final String? provides;
  final String? dataSentThere;

  Map<String, Object?> toJson() => _$DataExportSourceToJson(this);
}
