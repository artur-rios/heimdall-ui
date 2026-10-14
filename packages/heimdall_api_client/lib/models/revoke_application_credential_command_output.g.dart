// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'revoke_application_credential_command_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RevokeApplicationCredentialCommandOutput
_$RevokeApplicationCredentialCommandOutputFromJson(Map<String, dynamic> json) =>
    RevokeApplicationCredentialCommandOutput(
      id: json['id'] as String?,
      revokedAt: json['revokedAt'] == null
          ? null
          : DateTime.parse(json['revokedAt'] as String),
    );

Map<String, dynamic> _$RevokeApplicationCredentialCommandOutputToJson(
  RevokeApplicationCredentialCommandOutput instance,
) => <String, dynamic>{
  'id': instance.id,
  'revokedAt': instance.revokedAt?.toIso8601String(),
};
