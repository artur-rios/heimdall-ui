// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'data_export_subject.g.dart';

@JsonSerializable()
class DataExportSubject {
  const DataExportSubject({
    this.id,
    this.kind,
    this.name,
    this.email,
    this.emailVerified,
    this.role,
    this.googleId,
    this.profilePictureUrl,
    this.isDeleted,
    this.createdAt,
    this.updatedAt,
  });

  factory DataExportSubject.fromJson(Map<String, Object?> json) =>
      _$DataExportSubjectFromJson(json);

  final String? id;
  final String? kind;
  final String? name;
  final String? email;
  final bool? emailVerified;
  final int? role;
  final String? googleId;
  final String? profilePictureUrl;
  final bool? isDeleted;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Map<String, Object?> toJson() => _$DataExportSubjectToJson(this);
}
