// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'revoke_application_credential_command_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RevokeApplicationCredentialCommandOutput
_$RevokeApplicationCredentialCommandOutputFromJson(Map<String, dynamic> json) {
  $checkKeys(
    json,
    allowedKeys: const ['id', 'revokedAt'],
    disallowNullValues: const ['id', 'revokedAt'],
  );
  return RevokeApplicationCredentialCommandOutput(
    id: json['id'] as String?,
    revokedAt: RevokeApplicationCredentialCommandOutput._read_revokedAt(
      json['revokedAt'],
    ),
  );
}

Map<String, dynamic> _$RevokeApplicationCredentialCommandOutputToJson(
  RevokeApplicationCredentialCommandOutput instance,
) => <String, dynamic>{
  'id': ?instance.id,
  'revokedAt': ?RevokeApplicationCredentialCommandOutput._write_revokedAt(
    instance.revokedAt,
  ),
};
