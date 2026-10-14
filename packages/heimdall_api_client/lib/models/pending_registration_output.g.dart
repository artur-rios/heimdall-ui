// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pending_registration_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PendingRegistrationOutput _$PendingRegistrationOutputFromJson(
  Map<String, dynamic> json,
) => PendingRegistrationOutput(
  id: json['id'] as String?,
  name: json['name'] as String?,
  email: json['email'] as String?,
  createdAt: json['createdAt'] == null
      ? null
      : DateTime.parse(json['createdAt'] as String),
  expiresAt: json['expiresAt'] == null
      ? null
      : DateTime.parse(json['expiresAt'] as String),
  attemptsLeft: (json['attemptsLeft'] as num?)?.toInt(),
  expired: json['expired'] as bool?,
);

Map<String, dynamic> _$PendingRegistrationOutputToJson(
  PendingRegistrationOutput instance,
) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'email': instance.email,
  'createdAt': instance.createdAt?.toIso8601String(),
  'expiresAt': instance.expiresAt?.toIso8601String(),
  'attemptsLeft': instance.attemptsLeft,
  'expired': instance.expired,
};
