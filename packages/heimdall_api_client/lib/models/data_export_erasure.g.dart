// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'data_export_erasure.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DataExportErasure _$DataExportErasureFromJson(Map<String, dynamic> json) =>
    DataExportErasure(
      isDeleted: json['isDeleted'] as bool?,
      deletedAt: json['deletedAt'] == null
          ? null
          : DateTime.parse(json['deletedAt'] as String),
      deletionKind: (json['deletionKind'] as num?)?.toInt(),
      anonymisedAt: json['anonymisedAt'] == null
          ? null
          : DateTime.parse(json['anonymisedAt'] as String),
      erasureRequestedAt: json['erasureRequestedAt'] == null
          ? null
          : DateTime.parse(json['erasureRequestedAt'] as String),
      erasureDueAt: json['erasureDueAt'] == null
          ? null
          : DateTime.parse(json['erasureDueAt'] as String),
      erasureBlockedReason: json['erasureBlockedReason'] as String?,
    );

Map<String, dynamic> _$DataExportErasureToJson(DataExportErasure instance) =>
    <String, dynamic>{
      'isDeleted': instance.isDeleted,
      'deletedAt': instance.deletedAt?.toIso8601String(),
      'deletionKind': instance.deletionKind,
      'anonymisedAt': instance.anonymisedAt?.toIso8601String(),
      'erasureRequestedAt': instance.erasureRequestedAt?.toIso8601String(),
      'erasureDueAt': instance.erasureDueAt?.toIso8601String(),
      'erasureBlockedReason': instance.erasureBlockedReason,
    };
