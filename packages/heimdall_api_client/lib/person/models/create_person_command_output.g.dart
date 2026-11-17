// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_person_command_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreatePersonCommandOutput _$CreatePersonCommandOutputFromJson(
  Map<String, dynamic> json,
) {
  $checkKeys(
    json,
    allowedKeys: const [
      'id',
      'name',
      'email',
      'role',
      'emailVerified',
      'scopeId',
      'createdAt',
    ],
    disallowNullValues: const ['id', 'role', 'emailVerified', 'createdAt'],
  );
  return CreatePersonCommandOutput(
    id: json['id'] as String?,
    name: json['name'] as String?,
    email: json['email'] as String?,
    role: CreatePersonCommandOutput._read_role(json['role']),
    emailVerified: json['emailVerified'] as bool?,
    scopeId: json['scopeId'] as String?,
    createdAt: CreatePersonCommandOutput._read_createdAt(json['createdAt']),
  );
}

Map<String, dynamic> _$CreatePersonCommandOutputToJson(
  CreatePersonCommandOutput instance,
) => <String, dynamic>{
  'id': ?instance.id,
  'name': ?instance.name,
  'email': ?instance.email,
  'role': ?CreatePersonCommandOutput._write_role(instance.role),
  'emailVerified': ?instance.emailVerified,
  'scopeId': ?instance.scopeId,
  'createdAt': ?CreatePersonCommandOutput._write_createdAt(instance.createdAt),
};
