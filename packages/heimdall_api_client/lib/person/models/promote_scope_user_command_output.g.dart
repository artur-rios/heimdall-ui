// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'promote_scope_user_command_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PromoteScopeUserCommandOutput _$PromoteScopeUserCommandOutputFromJson(
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
  return PromoteScopeUserCommandOutput(
    id: json['id'] as String?,
    name: json['name'] as String?,
    email: json['email'] as String?,
    role: PromoteScopeUserCommandOutput._read_role(json['role']),
    emailVerified: json['emailVerified'] as bool?,
    ownedScopeIds: (json['ownedScopeIds'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList(),
    createdAt: PromoteScopeUserCommandOutput._read_createdAt(json['createdAt']),
    updatedAt: PromoteScopeUserCommandOutput._read_updatedAt(json['updatedAt']),
  );
}

Map<String, dynamic> _$PromoteScopeUserCommandOutputToJson(
  PromoteScopeUserCommandOutput instance,
) => <String, dynamic>{
  'id': ?instance.id,
  'name': ?instance.name,
  'email': ?instance.email,
  'role': ?PromoteScopeUserCommandOutput._write_role(instance.role),
  'emailVerified': ?instance.emailVerified,
  'ownedScopeIds': ?instance.ownedScopeIds,
  'createdAt': ?PromoteScopeUserCommandOutput._write_createdAt(
    instance.createdAt,
  ),
  'updatedAt': ?PromoteScopeUserCommandOutput._write_updatedAt(
    instance.updatedAt,
  ),
};
