// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'promote_scope_user_command_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PromoteScopeUserCommandOutput _$PromoteScopeUserCommandOutputFromJson(
  Map<String, dynamic> json,
) => PromoteScopeUserCommandOutput(
  id: json['id'] as String?,
  name: json['name'] as String?,
  email: json['email'] as String?,
  role: (json['role'] as num?)?.toInt(),
  emailVerified: json['emailVerified'] as bool?,
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

Map<String, dynamic> _$PromoteScopeUserCommandOutputToJson(
  PromoteScopeUserCommandOutput instance,
) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'email': instance.email,
  'role': instance.role,
  'emailVerified': instance.emailVerified,
  'ownedScopeIds': instance.ownedScopeIds,
  'createdAt': instance.createdAt?.toIso8601String(),
  'updatedAt': instance.updatedAt?.toIso8601String(),
};
