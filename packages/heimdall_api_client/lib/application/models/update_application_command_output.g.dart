// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'update_application_command_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UpdateApplicationCommandOutput _$UpdateApplicationCommandOutputFromJson(
  Map<String, dynamic> json,
) {
  $checkKeys(
    json,
    allowedKeys: const [
      'id',
      'name',
      'scopeId',
      'ownerId',
      'createdAt',
      'updatedAt',
    ],
    disallowNullValues: const [
      'id',
      'scopeId',
      'ownerId',
      'createdAt',
      'updatedAt',
    ],
  );
  return UpdateApplicationCommandOutput(
    id: json['id'] as String?,
    name: json['name'] as String?,
    scopeId: json['scopeId'] as String?,
    ownerId: json['ownerId'] as String?,
    createdAt: UpdateApplicationCommandOutput._read_createdAt(
      json['createdAt'],
    ),
    updatedAt: UpdateApplicationCommandOutput._read_updatedAt(
      json['updatedAt'],
    ),
  );
}

Map<String, dynamic> _$UpdateApplicationCommandOutputToJson(
  UpdateApplicationCommandOutput instance,
) => <String, dynamic>{
  'id': ?instance.id,
  'name': ?instance.name,
  'scopeId': ?instance.scopeId,
  'ownerId': ?instance.ownerId,
  'createdAt': ?UpdateApplicationCommandOutput._write_createdAt(
    instance.createdAt,
  ),
  'updatedAt': ?UpdateApplicationCommandOutput._write_updatedAt(
    instance.updatedAt,
  ),
};
