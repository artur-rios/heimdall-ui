// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'data_export_audit_entry.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DataExportAuditEntry _$DataExportAuditEntryFromJson(Map<String, dynamic> json) {
  $checkKeys(
    json,
    allowedKeys: const [
      'id',
      'involvement',
      'action',
      'targetId',
      'succeeded',
      'failureReason',
      'createdAt',
    ],
    disallowNullValues: const ['id', 'succeeded', 'createdAt'],
  );
  return DataExportAuditEntry(
    id: json['id'] as String?,
    involvement: json['involvement'] as String?,
    action: json['action'] as String?,
    targetId: json['targetId'] as String?,
    succeeded: json['succeeded'] as bool?,
    failureReason: json['failureReason'] as String?,
    createdAt: DataExportAuditEntry._read_createdAt(json['createdAt']),
  );
}

Map<String, dynamic> _$DataExportAuditEntryToJson(
  DataExportAuditEntry instance,
) => <String, dynamic>{
  'id': ?instance.id,
  'involvement': ?instance.involvement,
  'action': ?instance.action,
  'targetId': ?instance.targetId,
  'succeeded': ?instance.succeeded,
  'failureReason': ?instance.failureReason,
  'createdAt': ?DataExportAuditEntry._write_createdAt(instance.createdAt),
};
