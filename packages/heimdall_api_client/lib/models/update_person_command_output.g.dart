// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'update_person_command_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UpdatePersonCommandOutput _$UpdatePersonCommandOutputFromJson(
  Map<String, dynamic> json,
) => UpdatePersonCommandOutput(
  id: json['id'] as String?,
  name: json['name'] as String?,
  email: json['email'] as String?,
  role: (json['role'] as num?)?.toInt(),
  emailVerified: json['emailVerified'] as bool?,
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

Map<String, dynamic> _$UpdatePersonCommandOutputToJson(
  UpdatePersonCommandOutput instance,
) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'email': instance.email,
  'role': instance.role,
  'emailVerified': instance.emailVerified,
  'scopeId': instance.scopeId,
  'ownedScopeIds': instance.ownedScopeIds,
  'createdAt': instance.createdAt?.toIso8601String(),
  'updatedAt': instance.updatedAt?.toIso8601String(),
};
