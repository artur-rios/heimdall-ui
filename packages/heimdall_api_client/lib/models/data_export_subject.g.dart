// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'data_export_subject.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DataExportSubject _$DataExportSubjectFromJson(Map<String, dynamic> json) =>
    DataExportSubject(
      id: json['id'] as String?,
      kind: json['kind'] as String?,
      name: json['name'] as String?,
      email: json['email'] as String?,
      emailVerified: json['emailVerified'] as bool?,
      role: (json['role'] as num?)?.toInt(),
      googleId: json['googleId'] as String?,
      profilePictureUrl: json['profilePictureUrl'] as String?,
      isDeleted: json['isDeleted'] as bool?,
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$DataExportSubjectToJson(DataExportSubject instance) =>
    <String, dynamic>{
      'id': instance.id,
      'kind': instance.kind,
      'name': instance.name,
      'email': instance.email,
      'emailVerified': instance.emailVerified,
      'role': instance.role,
      'googleId': instance.googleId,
      'profilePictureUrl': instance.profilePictureUrl,
      'isDeleted': instance.isDeleted,
      'createdAt': instance.createdAt?.toIso8601String(),
      'updatedAt': instance.updatedAt?.toIso8601String(),
    };
