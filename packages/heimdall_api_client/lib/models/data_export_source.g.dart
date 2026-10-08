// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'data_export_source.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DataExportSource _$DataExportSourceFromJson(Map<String, dynamic> json) =>
    DataExportSource(
      name: json['name'] as String?,
      provides: json['provides'] as String?,
      dataSentThere: json['dataSentThere'] as String?,
    );

Map<String, dynamic> _$DataExportSourceToJson(DataExportSource instance) =>
    <String, dynamic>{
      'name': instance.name,
      'provides': instance.provides,
      'dataSentThere': instance.dataSentThere,
    };
