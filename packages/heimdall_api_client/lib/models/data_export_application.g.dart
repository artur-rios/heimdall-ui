// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'data_export_application.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DataExportApplication _$DataExportApplicationFromJson(
  Map<String, dynamic> json,
) => DataExportApplication(
  id: json['id'] as String?,
  name: json['name'] as String?,
  scopeId: json['scopeId'] as String?,
  isDeleted: json['isDeleted'] as bool?,
);

Map<String, dynamic> _$DataExportApplicationToJson(
  DataExportApplication instance,
) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'scopeId': instance.scopeId,
  'isDeleted': instance.isDeleted,
};
