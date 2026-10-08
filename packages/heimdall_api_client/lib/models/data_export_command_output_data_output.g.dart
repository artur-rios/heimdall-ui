// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'data_export_command_output_data_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DataExportCommandOutputDataOutput _$DataExportCommandOutputDataOutputFromJson(
  Map<String, dynamic> json,
) => DataExportCommandOutputDataOutput(
  messages: (json['messages'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  errors: (json['errors'] as List<dynamic>?)?.map((e) => e as String).toList(),
  timestamp: json['timestamp'] == null
      ? null
      : DateTime.parse(json['timestamp'] as String),
  success: json['success'] as bool?,
  data: json['data'] == null
      ? null
      : DataExportCommandOutput.fromJson(json['data'] as Map<String, dynamic>),
);

Map<String, dynamic> _$DataExportCommandOutputDataOutputToJson(
  DataExportCommandOutputDataOutput instance,
) => <String, dynamic>{
  'messages': instance.messages,
  'errors': instance.errors,
  'timestamp': instance.timestamp?.toIso8601String(),
  'success': instance.success,
  'data': instance.data,
};
