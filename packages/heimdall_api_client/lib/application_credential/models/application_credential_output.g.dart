// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'application_credential_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ApplicationCredentialOutput _$ApplicationCredentialOutputFromJson(
  Map<String, dynamic> json,
) {
  $checkKeys(
    json,
    allowedKeys: const [
      'id',
      'createdAt',
      'expiresAt',
      'revokedAt',
      'lastUsedAt',
      'live',
    ],
    disallowNullValues: const ['id', 'createdAt', 'live'],
  );
  return ApplicationCredentialOutput(
    id: json['id'] as String?,
    createdAt: ApplicationCredentialOutput._read_createdAt(json['createdAt']),
    expiresAt: ApplicationCredentialOutput._read_expiresAt(json['expiresAt']),
    revokedAt: ApplicationCredentialOutput._read_revokedAt(json['revokedAt']),
    lastUsedAt: ApplicationCredentialOutput._read_lastUsedAt(
      json['lastUsedAt'],
    ),
    live: json['live'] as bool?,
  );
}

Map<String, dynamic> _$ApplicationCredentialOutputToJson(
  ApplicationCredentialOutput instance,
) => <String, dynamic>{
  'id': ?instance.id,
  'createdAt': ?ApplicationCredentialOutput._write_createdAt(
    instance.createdAt,
  ),
  'expiresAt': ?ApplicationCredentialOutput._write_expiresAt(
    instance.expiresAt,
  ),
  'revokedAt': ?ApplicationCredentialOutput._write_revokedAt(
    instance.revokedAt,
  ),
  'lastUsedAt': ?ApplicationCredentialOutput._write_lastUsedAt(
    instance.lastUsedAt,
  ),
  'live': ?instance.live,
};
