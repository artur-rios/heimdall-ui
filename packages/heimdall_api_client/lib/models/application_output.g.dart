// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'application_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ApplicationOutput _$ApplicationOutputFromJson(Map<String, dynamic> json) =>
    ApplicationOutput(
      id: json['id'] as String?,
      name: json['name'] as String?,
      scopeId: json['scopeId'] as String?,
      ownerId: json['ownerId'] as String?,
      isDeleted: json['isDeleted'] as bool?,
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$ApplicationOutputToJson(ApplicationOutput instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'scopeId': instance.scopeId,
      'ownerId': instance.ownerId,
      'isDeleted': instance.isDeleted,
      'createdAt': instance.createdAt?.toIso8601String(),
      'updatedAt': instance.updatedAt?.toIso8601String(),
    };
