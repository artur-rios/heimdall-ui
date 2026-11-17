// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'person_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PersonOutput _$PersonOutputFromJson(Map<String, dynamic> json) {
  $checkKeys(
    json,
    allowedKeys: const [
      'id',
      'name',
      'email',
      'role',
      'emailVerified',
      'twoFactorEnabled',
      'isDeleted',
      'scopeId',
      'ownedScopeIds',
      'createdAt',
      'updatedAt',
    ],
    disallowNullValues: const [
      'id',
      'role',
      'emailVerified',
      'twoFactorEnabled',
      'isDeleted',
      'createdAt',
      'updatedAt',
    ],
  );
  return PersonOutput(
    id: json['id'] as String?,
    name: json['name'] as String?,
    email: json['email'] as String?,
    role: PersonOutput._read_role(json['role']),
    emailVerified: json['emailVerified'] as bool?,
    twoFactorEnabled: json['twoFactorEnabled'] as bool?,
    isDeleted: json['isDeleted'] as bool?,
    scopeId: json['scopeId'] as String?,
    ownedScopeIds: (json['ownedScopeIds'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList(),
    createdAt: PersonOutput._read_createdAt(json['createdAt']),
    updatedAt: PersonOutput._read_updatedAt(json['updatedAt']),
  );
}

Map<String, dynamic> _$PersonOutputToJson(PersonOutput instance) =>
    <String, dynamic>{
      'id': ?instance.id,
      'name': ?instance.name,
      'email': ?instance.email,
      'role': ?PersonOutput._write_role(instance.role),
      'emailVerified': ?instance.emailVerified,
      'twoFactorEnabled': ?instance.twoFactorEnabled,
      'isDeleted': ?instance.isDeleted,
      'scopeId': ?instance.scopeId,
      'ownedScopeIds': ?instance.ownedScopeIds,
      'createdAt': ?PersonOutput._write_createdAt(instance.createdAt),
      'updatedAt': ?PersonOutput._write_updatedAt(instance.updatedAt),
    };
