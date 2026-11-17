// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'update_person_command_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UpdatePersonCommandOutput _$UpdatePersonCommandOutputFromJson(
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
      'ownedScopeIds',
      'createdAt',
      'updatedAt',
    ],
    disallowNullValues: const [
      'id',
      'role',
      'emailVerified',
      'createdAt',
      'updatedAt',
    ],
  );
  return UpdatePersonCommandOutput(
    id: json['id'] as String?,
    name: json['name'] as String?,
    email: json['email'] as String?,
    role: UpdatePersonCommandOutput._read_role(json['role']),
    emailVerified: json['emailVerified'] as bool?,
    scopeId: json['scopeId'] as String?,
    ownedScopeIds: (json['ownedScopeIds'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList(),
    createdAt: UpdatePersonCommandOutput._read_createdAt(json['createdAt']),
    updatedAt: UpdatePersonCommandOutput._read_updatedAt(json['updatedAt']),
  );
}

Map<String, dynamic> _$UpdatePersonCommandOutputToJson(
  UpdatePersonCommandOutput instance,
) => <String, dynamic>{
  'id': ?instance.id,
  'name': ?instance.name,
  'email': ?instance.email,
  'role': ?UpdatePersonCommandOutput._write_role(instance.role),
  'emailVerified': ?instance.emailVerified,
  'scopeId': ?instance.scopeId,
  'ownedScopeIds': ?instance.ownedScopeIds,
  'createdAt': ?UpdatePersonCommandOutput._write_createdAt(instance.createdAt),
  'updatedAt': ?UpdatePersonCommandOutput._write_updatedAt(instance.updatedAt),
};
