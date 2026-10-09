// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'data_export_application.dart';
import 'data_export_audit_entry.dart';
import 'data_export_erasure.dart';
import 'data_export_processing.dart';
import 'data_export_recipient.dart';
import 'data_export_retention.dart';
import 'data_export_security.dart';
import 'data_export_source.dart';
import 'data_export_subject.dart';
import 'data_export_withheld.dart';

part 'data_export_command_output.g.dart';

@JsonSerializable()
class DataExportCommandOutput {
  const DataExportCommandOutput({
    required this.subject,
    required this.security,
    required this.processing,
    this.exportedAt,
    this.erasure,
    this.scopeMemberships,
    this.scopeOwnerships,
    this.applications,
    this.auditEntries,
    this.auditEntriesTruncated,
    this.withheld,
    this.recipients,
    this.sources,
    this.retention,
  });

  factory DataExportCommandOutput.fromJson(Map<String, Object?> json) =>
      _$DataExportCommandOutputFromJson(json);

  final DateTime? exportedAt;
  final DataExportSubject subject;
  final DataExportSecurity security;
  final DataExportProcessing processing;
  final DataExportErasure? erasure;
  final List<String>? scopeMemberships;
  final List<String>? scopeOwnerships;
  final List<DataExportApplication>? applications;
  final List<DataExportAuditEntry>? auditEntries;
  final bool? auditEntriesTruncated;
  final List<DataExportWithheld>? withheld;
  final List<DataExportRecipient>? recipients;
  final List<DataExportSource>? sources;
  final List<DataExportRetention>? retention;

  Map<String, Object?> toJson() => _$DataExportCommandOutputToJson(this);
}
