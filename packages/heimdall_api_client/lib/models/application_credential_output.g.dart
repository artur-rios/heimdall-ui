// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'application_credential_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ApplicationCredentialOutput _$ApplicationCredentialOutputFromJson(
  Map<String, dynamic> json,
) => ApplicationCredentialOutput(
  id: json['id'] as String?,
  createdAt: json['createdAt'] == null
      ? null
      : DateTime.parse(json['createdAt'] as String),
  expiresAt: json['expiresAt'] == null
      ? null
      : DateTime.parse(json['expiresAt'] as String),
  revokedAt: json['revokedAt'] == null
      ? null
      : DateTime.parse(json['revokedAt'] as String),
  lastUsedAt: json['lastUsedAt'] == null
      ? null
      : DateTime.parse(json['lastUsedAt'] as String),
  live: json['live'] as bool?,
);

Map<String, dynamic> _$ApplicationCredentialOutputToJson(
  ApplicationCredentialOutput instance,
) => <String, dynamic>{
  'id': instance.id,
  'createdAt': instance.createdAt?.toIso8601String(),
  'expiresAt': instance.expiresAt?.toIso8601String(),
  'revokedAt': instance.revokedAt?.toIso8601String(),
  'lastUsedAt': instance.lastUsedAt?.toIso8601String(),
  'live': instance.live,
};
