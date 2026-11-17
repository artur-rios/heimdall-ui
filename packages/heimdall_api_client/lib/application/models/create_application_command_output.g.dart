// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_application_command_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreateApplicationCommandOutput _$CreateApplicationCommandOutputFromJson(
  Map<String, dynamic> json,
) {
  $checkKeys(
    json,
    allowedKeys: const ['id', 'name', 'scopeId', 'ownerId', 'createdAt'],
    disallowNullValues: const ['id', 'scopeId', 'ownerId', 'createdAt'],
  );
  return CreateApplicationCommandOutput(
    id: json['id'] as String?,
    name: json['name'] as String?,
    scopeId: json['scopeId'] as String?,
    ownerId: json['ownerId'] as String?,
    createdAt: CreateApplicationCommandOutput._read_createdAt(
      json['createdAt'],
    ),
  );
}

Map<String, dynamic> _$CreateApplicationCommandOutputToJson(
  CreateApplicationCommandOutput instance,
) => <String, dynamic>{
  'id': ?instance.id,
  'name': ?instance.name,
  'scopeId': ?instance.scopeId,
  'ownerId': ?instance.ownerId,
  'createdAt': ?CreateApplicationCommandOutput._write_createdAt(
    instance.createdAt,
  ),
};
