// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'person_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PersonOutput _$PersonOutputFromJson(Map<String, dynamic> json) => PersonOutput(
  id: json['id'] as String?,
  name: json['name'] as String?,
  email: json['email'] as String?,
  role: (json['role'] as num?)?.toInt(),
  emailVerified: json['emailVerified'] as bool?,
  twoFactorEnabled: json['twoFactorEnabled'] as bool?,
  isDeleted: json['isDeleted'] as bool?,
  scopeId: json['scopeId'] as String?,
  ownedScopeIds: (json['ownedScopeIds'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  createdAt: json['createdAt'] == null
      ? null
      : DateTime.parse(json['createdAt'] as String),
  updatedAt: json['updatedAt'] == null
      ? null
      : DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$PersonOutputToJson(PersonOutput instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'email': instance.email,
      'role': instance.role,
      'emailVerified': instance.emailVerified,
      'twoFactorEnabled': instance.twoFactorEnabled,
      'isDeleted': instance.isDeleted,
      'scopeId': instance.scopeId,
      'ownedScopeIds': instance.ownedScopeIds,
      'createdAt': instance.createdAt?.toIso8601String(),
      'updatedAt': instance.updatedAt?.toIso8601String(),
    };
