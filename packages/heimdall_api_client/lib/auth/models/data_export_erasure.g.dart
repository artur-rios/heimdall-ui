// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'data_export_erasure.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DataExportErasure _$DataExportErasureFromJson(Map<String, dynamic> json) {
  $checkKeys(
    json,
    allowedKeys: const [
      'isDeleted',
      'deletedAt',
      'deletionKind',
      'anonymisedAt',
      'erasureRequestedAt',
      'erasureDueAt',
      'erasureBlockedReason',
    ],
    disallowNullValues: const ['isDeleted'],
  );
  return DataExportErasure(
    isDeleted: json['isDeleted'] as bool?,
    deletedAt: DataExportErasure._read_deletedAt(json['deletedAt']),
    deletionKind: DataExportErasure._read_deletionKind(json['deletionKind']),
    anonymisedAt: DataExportErasure._read_anonymisedAt(json['anonymisedAt']),
    erasureRequestedAt: DataExportErasure._read_erasureRequestedAt(
      json['erasureRequestedAt'],
    ),
    erasureDueAt: DataExportErasure._read_erasureDueAt(json['erasureDueAt']),
    erasureBlockedReason: json['erasureBlockedReason'] as String?,
  );
}

Map<String, dynamic> _$DataExportErasureToJson(
  DataExportErasure instance,
) => <String, dynamic>{
  'isDeleted': ?instance.isDeleted,
  'deletedAt': ?DataExportErasure._write_deletedAt(instance.deletedAt),
  'deletionKind': ?DataExportErasure._write_deletionKind(instance.deletionKind),
  'anonymisedAt': ?DataExportErasure._write_anonymisedAt(instance.anonymisedAt),
  'erasureRequestedAt': ?DataExportErasure._write_erasureRequestedAt(
    instance.erasureRequestedAt,
  ),
  'erasureDueAt': ?DataExportErasure._write_erasureDueAt(instance.erasureDueAt),
  'erasureBlockedReason': ?instance.erasureBlockedReason,
};
