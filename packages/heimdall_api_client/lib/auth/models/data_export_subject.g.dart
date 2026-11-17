// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'data_export_subject.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DataExportSubject _$DataExportSubjectFromJson(Map<String, dynamic> json) {
  $checkKeys(
    json,
    allowedKeys: const [
      'id',
      'kind',
      'name',
      'email',
      'emailVerified',
      'role',
      'googleId',
      'profilePictureUrl',
      'isDeleted',
      'createdAt',
      'updatedAt',
    ],
    disallowNullValues: const [
      'id',
      'emailVerified',
      'isDeleted',
      'createdAt',
      'updatedAt',
    ],
  );
  return DataExportSubject(
    id: json['id'] as String?,
    kind: json['kind'] as String?,
    name: json['name'] as String?,
    email: json['email'] as String?,
    emailVerified: json['emailVerified'] as bool?,
    role: DataExportSubject._read_role(json['role']),
    googleId: json['googleId'] as String?,
    profilePictureUrl: json['profilePictureUrl'] as String?,
    isDeleted: json['isDeleted'] as bool?,
    createdAt: DataExportSubject._read_createdAt(json['createdAt']),
    updatedAt: DataExportSubject._read_updatedAt(json['updatedAt']),
  );
}

Map<String, dynamic> _$DataExportSubjectToJson(DataExportSubject instance) =>
    <String, dynamic>{
      'id': ?instance.id,
      'kind': ?instance.kind,
      'name': ?instance.name,
      'email': ?instance.email,
      'emailVerified': ?instance.emailVerified,
      'role': ?DataExportSubject._write_role(instance.role),
      'googleId': ?instance.googleId,
      'profilePictureUrl': ?instance.profilePictureUrl,
      'isDeleted': ?instance.isDeleted,
      'createdAt': ?DataExportSubject._write_createdAt(instance.createdAt),
      'updatedAt': ?DataExportSubject._write_updatedAt(instance.updatedAt),
    };
