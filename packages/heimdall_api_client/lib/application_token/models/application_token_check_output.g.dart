// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'application_token_check_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ApplicationTokenCheckOutput _$ApplicationTokenCheckOutputFromJson(
  Map<String, dynamic> json,
) {
  $checkKeys(
    json,
    allowedKeys: const [
      'applicationId',
      'name',
      'scopeId',
      'credentialId',
      'expiresAt',
    ],
    disallowNullValues: const [
      'applicationId',
      'scopeId',
      'credentialId',
      'expiresAt',
    ],
  );
  return ApplicationTokenCheckOutput(
    applicationId: json['applicationId'] as String?,
    name: json['name'] as String?,
    scopeId: json['scopeId'] as String?,
    credentialId: json['credentialId'] as String?,
    expiresAt: ApplicationTokenCheckOutput._read_expiresAt(json['expiresAt']),
  );
}

Map<String, dynamic> _$ApplicationTokenCheckOutputToJson(
  ApplicationTokenCheckOutput instance,
) => <String, dynamic>{
  'applicationId': ?instance.applicationId,
  'name': ?instance.name,
  'scopeId': ?instance.scopeId,
  'credentialId': ?instance.credentialId,
  'expiresAt': ?ApplicationTokenCheckOutput._write_expiresAt(
    instance.expiresAt,
  ),
};
