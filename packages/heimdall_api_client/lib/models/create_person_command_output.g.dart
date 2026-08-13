// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_person_command_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreatePersonCommandOutput _$CreatePersonCommandOutputFromJson(
  Map<String, dynamic> json,
) => CreatePersonCommandOutput(
  id: json['id'] as String?,
  name: json['name'] as String?,
  email: json['email'] as String?,
  role: (json['role'] as num?)?.toInt(),
  emailVerified: json['emailVerified'] as bool?,
  scopeId: json['scopeId'] as String?,
  createdAt: json['createdAt'] == null
      ? null
      : DateTime.parse(json['createdAt'] as String),
);

Map<String, dynamic> _$CreatePersonCommandOutputToJson(
  CreatePersonCommandOutput instance,
) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'email': instance.email,
  'role': instance.role,
  'emailVerified': instance.emailVerified,
  'scopeId': instance.scopeId,
  'createdAt': instance.createdAt?.toIso8601String(),
};
