// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'application_output_paginated_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ApplicationOutputPaginatedOutput _$ApplicationOutputPaginatedOutputFromJson(
  Map<String, dynamic> json,
) => ApplicationOutputPaginatedOutput(
  messages: (json['messages'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  errors: (json['errors'] as List<dynamic>?)?.map((e) => e as String).toList(),
  timestamp: json['timestamp'] == null
      ? null
      : DateTime.parse(json['timestamp'] as String),
  success: json['success'] as bool?,
  data: (json['data'] as List<dynamic>?)
      ?.map((e) => ApplicationOutput.fromJson(e as Map<String, dynamic>))
      .toList(),
  pageNumber: (json['pageNumber'] as num?)?.toInt(),
  pageSize: (json['pageSize'] as num?)?.toInt(),
  totalItems: (json['totalItems'] as num?)?.toInt(),
  totalPages: (json['totalPages'] as num?)?.toInt(),
);

Map<String, dynamic> _$ApplicationOutputPaginatedOutputToJson(
  ApplicationOutputPaginatedOutput instance,
) => <String, dynamic>{
  'messages': instance.messages,
  'errors': instance.errors,
  'timestamp': instance.timestamp?.toIso8601String(),
  'success': instance.success,
  'data': instance.data,
  'pageNumber': instance.pageNumber,
  'pageSize': instance.pageSize,
  'totalItems': instance.totalItems,
  'totalPages': instance.totalPages,
};
