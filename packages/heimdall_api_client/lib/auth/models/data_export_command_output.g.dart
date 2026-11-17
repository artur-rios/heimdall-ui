// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'data_export_command_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DataExportCommandOutput _$DataExportCommandOutputFromJson(
  Map<String, dynamic> json,
) {
  $checkKeys(
    json,
    allowedKeys: const [
      'exportedAt',
      'subject',
      'security',
      'processing',
      'erasure',
      'scopeMemberships',
      'scopeOwnerships',
      'applications',
      'auditEntries',
      'auditEntriesTruncated',
      'withheld',
      'recipients',
      'sources',
      'retention',
    ],
    requiredKeys: const ['subject', 'security', 'processing'],
    disallowNullValues: const [
      'exportedAt',
      'subject',
      'security',
      'processing',
      'auditEntriesTruncated',
    ],
  );
  return DataExportCommandOutput(
    exportedAt: DataExportCommandOutput._read_exportedAt(json['exportedAt']),
    subject: DataExportSubject.fromJson(
      json['subject'] as Map<String, dynamic>,
    ),
    security: DataExportSecurity.fromJson(
      json['security'] as Map<String, dynamic>,
    ),
    processing: DataExportProcessing.fromJson(
      json['processing'] as Map<String, dynamic>,
    ),
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
}

Map<String, dynamic> _$DataExportCommandOutputToJson(
  DataExportCommandOutput instance,
) => <String, dynamic>{
  'exportedAt': ?DataExportCommandOutput._write_exportedAt(instance.exportedAt),
  'subject': instance.subject.toJson(),
  'security': instance.security.toJson(),
  'processing': instance.processing.toJson(),
  'erasure': ?instance.erasure?.toJson(),
  'scopeMemberships': ?instance.scopeMemberships,
  'scopeOwnerships': ?instance.scopeOwnerships,
  'applications': ?instance.applications?.map((e) => e.toJson()).toList(),
  'auditEntries': ?instance.auditEntries?.map((e) => e.toJson()).toList(),
  'auditEntriesTruncated': ?instance.auditEntriesTruncated,
  'withheld': ?instance.withheld?.map((e) => e.toJson()).toList(),
  'recipients': ?instance.recipients?.map((e) => e.toJson()).toList(),
  'sources': ?instance.sources?.map((e) => e.toJson()).toList(),
  'retention': ?instance.retention?.map((e) => e.toJson()).toList(),
};
