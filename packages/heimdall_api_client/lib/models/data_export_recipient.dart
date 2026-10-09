// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'data_export_recipient.g.dart';

@JsonSerializable()
class DataExportRecipient {
  const DataExportRecipient({this.name, this.purpose, this.location});

  factory DataExportRecipient.fromJson(Map<String, Object?> json) =>
      _$DataExportRecipientFromJson(json);

  final String? name;
  final String? purpose;
  final String? location;

  Map<String, Object?> toJson() => _$DataExportRecipientToJson(this);
}
