// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'data_export_command_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DataExportCommandOutput _$DataExportCommandOutputFromJson(
  Map<String, dynamic> json,
) => DataExportCommandOutput(
  subject: DataExportSubject.fromJson(json['subject'] as Map<String, dynamic>),
  security: DataExportSecurity.fromJson(
    json['security'] as Map<String, dynamic>,
  ),
  processing: DataExportProcessing.fromJson(
    json['processing'] as Map<String, dynamic>,
  ),
  exportedAt: json['exportedAt'] == null
      ? null
      : DateTime.parse(json['exportedAt'] as String),
  erasure: json['erasure'] == null
      ? null
      : DataExportErasure.fromJson(json['erasure'] as Map<String, dynamic>),
  scopeMemberships: (json['scopeMemberships'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  scopeOwnerships: (json['scopeOwnerships'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  applications: (json['applications'] as List<dynamic>?)
      ?.map((e) => DataExportApplication.fromJson(e as Map<String, dynamic>))
      .toList(),
  auditEntries: (json['auditEntries'] as List<dynamic>?)
      ?.map((e) => DataExportAuditEntry.fromJson(e as Map<String, dynamic>))
      .toList(),
  auditEntriesTruncated: json['auditEntriesTruncated'] as bool?,
  withheld: (json['withheld'] as List<dynamic>?)
      ?.map((e) => DataExportWithheld.fromJson(e as Map<String, dynamic>))
      .toList(),
  recipients: (json['recipients'] as List<dynamic>?)
      ?.map((e) => DataExportRecipient.fromJson(e as Map<String, dynamic>))
      .toList(),
  sources: (json['sources'] as List<dynamic>?)
      ?.map((e) => DataExportSource.fromJson(e as Map<String, dynamic>))
      .toList(),
  retention: (json['retention'] as List<dynamic>?)
      ?.map((e) => DataExportRetention.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$DataExportCommandOutputToJson(
  DataExportCommandOutput instance,
) => <String, dynamic>{
  'exportedAt': instance.exportedAt?.toIso8601String(),
  'subject': instance.subject,
  'security': instance.security,
  'processing': instance.processing,
  'erasure': instance.erasure,
  'scopeMemberships': instance.scopeMemberships,
  'scopeOwnerships': instance.scopeOwnerships,
  'applications': instance.applications,
  'auditEntries': instance.auditEntries,
  'auditEntriesTruncated': instance.auditEntriesTruncated,
  'withheld': instance.withheld,
  'recipients': instance.recipients,
  'sources': instance.sources,
  'retention': instance.retention,
};
