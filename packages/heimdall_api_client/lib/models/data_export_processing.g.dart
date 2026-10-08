// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'data_export_processing.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DataExportProcessing _$DataExportProcessingFromJson(
  Map<String, dynamic> json,
) => DataExportProcessing(
  legalBasis: (json['legalBasis'] as num?)?.toInt(),
  legalBasisName: json['legalBasisName'] as String?,
  privacyNoticeVersion: json['privacyNoticeVersion'] as String?,
  recordedAt: json['recordedAt'] == null
      ? null
      : DateTime.parse(json['recordedAt'] as String),
);

Map<String, dynamic> _$DataExportProcessingToJson(
  DataExportProcessing instance,
) => <String, dynamic>{
  'legalBasis': instance.legalBasis,
  'legalBasisName': instance.legalBasisName,
  'privacyNoticeVersion': instance.privacyNoticeVersion,
  'recordedAt': instance.recordedAt?.toIso8601String(),
};
