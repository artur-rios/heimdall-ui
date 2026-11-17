// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'application_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ApplicationOutput _$ApplicationOutputFromJson(Map<String, dynamic> json) {
  $checkKeys(
    json,
    allowedKeys: const [
      'id',
      'name',
      'scopeId',
      'ownerId',
      'isDeleted',
      'createdAt',
      'updatedAt',
    ],
    disallowNullValues: const [
      'id',
      'scopeId',
      'ownerId',
      'isDeleted',
      'createdAt',
      'updatedAt',
    ],
  );
  return ApplicationOutput(
    id: json['id'] as String?,
    name: json['name'] as String?,
    scopeId: json['scopeId'] as String?,
    ownerId: json['ownerId'] as String?,
    isDeleted: json['isDeleted'] as bool?,
    createdAt: ApplicationOutput._read_createdAt(json['createdAt']),
    updatedAt: ApplicationOutput._read_updatedAt(json['updatedAt']),
  );
}

Map<String, dynamic> _$ApplicationOutputToJson(ApplicationOutput instance) =>
    <String, dynamic>{
      'id': ?instance.id,
      'name': ?instance.name,
      'scopeId': ?instance.scopeId,
      'ownerId': ?instance.ownerId,
      'isDeleted': ?instance.isDeleted,
      'createdAt': ?ApplicationOutput._write_createdAt(instance.createdAt),
      'updatedAt': ?ApplicationOutput._write_updatedAt(instance.updatedAt),
    };
