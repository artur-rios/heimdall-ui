// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'data_export_processing.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DataExportProcessing _$DataExportProcessingFromJson(Map<String, dynamic> json) {
  $checkKeys(
    json,
    allowedKeys: const [
      'legalBasis',
      'legalBasisName',
      'privacyNoticeVersion',
      'recordedAt',
    ],
    disallowNullValues: const ['legalBasis'],
  );
  return DataExportProcessing(
    legalBasis: DataExportProcessing._read_legalBasis(json['legalBasis']),
    legalBasisName: json['legalBasisName'] as String?,
    privacyNoticeVersion: json['privacyNoticeVersion'] as String?,
    recordedAt: DataExportProcessing._read_recordedAt(json['recordedAt']),
  );
}

Map<String, dynamic> _$DataExportProcessingToJson(
  DataExportProcessing instance,
) => <String, dynamic>{
  'legalBasis': ?DataExportProcessing._write_legalBasis(instance.legalBasis),
  'legalBasisName': ?instance.legalBasisName,
  'privacyNoticeVersion': ?instance.privacyNoticeVersion,
  'recordedAt': ?DataExportProcessing._write_recordedAt(instance.recordedAt),
};
